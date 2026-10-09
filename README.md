# ~/.dotfiles

Personal macOS config: **nix-darwin** (system) + **Home Manager** (user), driven by this flake.

Hosts `le` and `lex` are entries in the `hosts` table in `flake.nix` (hostname → macOS username). Nothing else names a user or a `/Users/<name>` path: home directories, `system.primaryUser`, Home Manager, Homebrew and nix trusted-users derive from that entry, and `just check` fails on a hardcoded one.

## Daily commands

| Command | What it does |
|---|---|
| `just switch` | Full nix-darwin rebuild + activate. Needs sudo. Same OmniWM settings.toml preflight as `just home`. |
| `just home` | Home Manager only. No sudo. Use for zsh / `home.file` / secretspec materialization. If `~/.config/omniwm/settings.toml` is a regular file, reviews the diff then y/N before replacing it with the repo symlink. |
| `just openbao-login` | Keycloak SSO → `~/.vault-token`. Required before activation can pull secrets. |
| `just secretspec-status` | Read-only: each secret's sync state against OpenBao (in-sync, behind, ahead, …), then a check that the `secretspec` CLI still reads the values this engine writes. |
| `just secretspec-sync` | Review the secrets that need a decision and push or pull them. Needs a terminal. `just secretspec-sync --push NAME` pushes the local file of one secret without prompts. |
| `just test-secrets` | Engine tests against a throwaway `bao server -dev` (needs `bao`, `jq`, `python3`; no network). Part of `just validate`. |
| `just secretspec-enforce-cas` | Once, after both Macs run this engine: OpenBao then refuses writes to the secrets without check-and-set. Needs the `patch` capability on `secret/metadata/secretspec/dotfiles/default/*`. |
| `just update-all` | `just update` → `just switch` → `just brew-upgrade`. |
| `just brew-upgrade` | `brew upgrade` on demand. `just switch` does **not** upgrade Homebrew. Runs `just switch` first when `flake.lock` is newer than the active system (taps sync on switch). Casks that remove launchctl services (VS Code, Discord) prompt for sudo mid-run; a shell `sudo -v` can't pre-authorise Homebrew's own sudo. |
| `just update` | `nix flake update` (lockfile only). |
| `just gc` | `nix-collect-garbage -d`. |
| `just --list` | Everything else (`check`, `fmt`, `lint`, `build`, `trace`). |


`just` with no args runs `switch`.

After `just home` / `just switch`, a **new shell** (or `exec zsh`) is required for zshrc / keymap changes. Running shells keep the old init.

## Layout

```
flake.nix                 hosts table (hostname → username) → darwinConfigurations
justfile                  the commands above
lib/builders.nix          mkDarwin: HM, nix-homebrew, overlays
hosts/<name>/             optional host-only tweaks (hosts/le: display mode)
hosts/common/             shared darwin defaults (owner name, nix, TouchID sudo, keyboard)
profiles/development.nix  CLI / k8s / fonts
profiles/personal.nix     Homebrew casks + personal packages
home/default.nix          Home Manager: packages, programs.*, activation
home/zsh/                 zshrc + aliases / options / keybindings
secretspec.toml           secret *names* only (no values)
home/secretspec/          secret-sync engine (materialize.sh + libs, tests), nix wrapper, secretspec provider aliases
home/omniwm/              OmniWM settings.toml (out-of-store symlink) + adopt.sh
home/herdr/               herdr config.toml + herdr-plus quick-actions
infra/                    Proxmox VMs: Terragrunt unit, secretspec manifest (names only), leak check, VM scripts
hosts/nixos/              generic NixOS guest role (proxmox-guest, role clean)
modules/nixos/            agent-dev: the module behind role agent (proxmox-agent), with the pinned omp
home/linux/               Home Manager of the agent role's user (not the Mac's home/default.nix)
```

Profiles are boolean toggles on `lib.mkDarwin` in `flake.nix`, not files under `hosts/common/profiles/`.

## Secrets

Live path is **homelab OpenBao**, not SOPS. `home/secretspec/materialize.sh` keeps the 14 secret files in sync with it. The nix wrapper `dotfiles-secrets` (in `home.packages`) pins its `bao`, `jq` and coreutils, so your own `bao` is left alone. The `just secretspec-*` recipes run the wrapper of the active Home Manager generation, so they work right after `just home`; a bare `dotfiles-secrets` on PATH only follows `just switch`.

- Manifest: `secretspec.toml` (`[profiles.default]`) lists the names. The table of names, paths and modes is in `materialize.sh`; a test keeps the two lists equal.
- Values: `secret/secretspec/dotfiles/default/<NAME>` on `https://openbao.home.0dl.me` (KV v2, field `value`). Every file is byte-exact, trailing newlines included.
- Direction is proven, not guessed. Each Mac keeps one record per secret, `~/.local/state/dotfiles/secretspec/<NAME>.base.json`: the vault version and bytes both sides last agreed on. KV v2 version numbers and bytes decide; clocks are display only.
- Activation: `home.activation.secretspecSecrets` runs `dotfiles-secrets apply` on every `just home` / `just switch`. It pulls what is safe (no local file, or only the vault changed), never writes the vault and never prompts. Anything that needs a human (local edits, both sides changed, vault rewound or empty, no record, a symlink in the way) prints one banner that points at `just secretspec-sync`, and the switch goes on.
- Vault unreachable (network, timeout, 5xx, 429, sealed): files are kept and the switch goes on for up to 7 days after the last successful contact. Rejected credentials (401/403) fail with the fix (`just openbao-login`); a TLS error fails and says to install the CA that signed the certificate. A secret missing from both the vault and this Mac always fails.
- Atuin sync login: `home.activation.atuinLogin` runs `home/secretspec/atuin-login.sh` after materialize and Home Manager's `linkGeneration` (it needs `config.toml`; any earlier, atuin writes its default config and targets Atuin's hosted server). `atuin status` OK → nothing (password not read). Otherwise `atuin login -u loneexile --key ""` with `ATUIN_PASSWORD` from OpenBao (argv only, never on disk); `--key ""` reuses the synced key file without rewriting it, so `ATUIN_KEY` stays in sync. Login/network failures print a `!!!!` banner and activation continues; `ATUIN_PASSWORD` missing while logged out fails activation.
- Status, review, push: `just secretspec-status` (read-only). `just secretspec-sync` (terminal): masked summaries that never print values, `v` for a read-only `nvim` diff of private copies (when both sides changed, the base is the middle window), `m` to merge, and a one-slot backup in `~/.local/state/dotfiles/secretspec/backup/<NAME>` before "take vault" or before a merge replaces the file. `just secretspec-sync --push NAME` pushes one file without prompts. Every push is check-and-set and is read back.
- **Never `secretspec delete` these keys.** It destroys every version and the history the engine reasons from. `secretspec set` drops the `writer` field and writes without check-and-set; use `just secretspec-sync --push NAME` instead.
- Login: `just openbao-login` (recipe name is `openbao-login`, not `secretspec-login`).
- Binary: `~/.cargo/bin/secretspec` (install script, not the nixpkgs package) is still used by `atuin-login.sh` (`ATUIN_PASSWORD`) and by the contract check in `just secretspec-status`. The sync engine does not call it.
- Tests: `just test-secrets`.

SOPS is leftover, not live: no `secrets/secrets.yaml`, no `sops.secrets.*` in any host/profile. What remains is the `sops-nix` input, `mkDarwin`'s unused darwin module, `.sops.yaml`, and `secrets/note.md`. Ignore those; do not put tokens in `programs.atuin.settings` or git.

Edited a secret file? `just secretspec-sync --push NAME` (or `just secretspec-sync` to review everything).

## Proxmox VMs

NixOS guests on Proxmox, provisioned with Terragrunt + OpenTofu (`bpg/proxmox`) and installed with `nixos-anywhere`. Each VM entry picks a role: `clean` (the default: the generic guest `hosts/nixos/proxmox-guest`, `nixosConfigurations.proxmox-guest`) or `agent` (the same guest plus the `agent-dev` module, `nixosConfigurations.proxmox-agent`; see **Roles**). The VM's identity is fixed at install: `vm-install` writes the hostname, the static network file and root's SSH keys onto the new system from the VM's entry in the vault, and NixOS runs no cloud-init at all (the Proxmox cloud-init drive only serves the Debian bootstrap stage and is ignored afterwards; see **Identity: fixed at install**). The root disk is LUKS2 and every boot waits for its passphrase (see **Disk encryption and unlock**). Root login by key only, and no QEMU guest agent: the VM has no command channel from Proxmox into the guest, and nothing on it reads the cloud-init drive. The clean role has no other user and no Home Manager; the agent role adds one login user without sudo (see **Roles**).

**What lives where.** The repo holds no server value, not even in docs or comments. `just infra-leak-check` catches the Proxmox endpoint host, token id and secret, state passphrase, the S3 endpoint host, the S3 secret key, every VM LUKS passphrase, and every VM name, IPv4, MAC and gateway, in tracked file contents. It does not catch the S3 access key id (it equals the project name), the bucket, node, datastore and bridge names, vmids, sizing, DNS resolvers, the initrd host public keys (public by design), tracked path names, commit messages or git history; those stay with the author. Placeholders below: `<endpoint>`, `<bucket>`, `<name>`, `<ipv4>`, `<vmid>`, `<node>`.

- Repo: `infra/` (Terragrunt unit `infra/proxmox/vms`, `infra/root.hcl`, `infra/secretspec.toml` = key *names* only), `hosts/nixos/proxmox-guest/` (role clean), `modules/nixos/agent-dev.nix` with `modules/nixos/agent-dev/omp.nix` and `home/linux/` (role agent).
- OpenBao: the `dotfiles-infra` project, `secret/secretspec/dotfiles-infra/default/<KEY>`. Keys: `TF_VAR_proxmox_endpoint`, `TF_VAR_proxmox_api_token` (full `user@realm!id=secret` form), `TF_VAR_proxmox_insecure`, `TF_VAR_image_datastore`, `TF_VAR_vm_datastore`, `TF_VAR_network_bridge`, `TF_VAR_vms`, `TF_VAR_ssh_authorized_keys` (a reference to `SSH_ID_ED25519_PUB` of the root manifest, one copy), `TF_VAR_tofu_state_passphrase`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (the dedicated S3 state user; the OpenTofu s3 backend reads both from the environment), `TF_STATE_S3_ENDPOINT` (`http://<endpoint>:<port>`), `TF_STATE_S3_BUCKET`, and two JSON maps keyed by VM name that `vm-install` maintains: `VM_LUKS_KEYS` (the disk passphrase of each VM) and `VM_INITRD_HOST_KEYS` (the public key of each VM's initrd SSH host key). Seed both maps once with `{}` (`printf '{}' | secretspec set VM_LUKS_KEYS`, same for `VM_INITRD_HOST_KEYS`, with `SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra"` exported); both keys are required, so `infra-plan` and the leak check fail until they exist.
- State: the S3 bucket `<bucket>` on the RustFS at `<endpoint>`, key `dotfiles-infra/proxmox-vms/terraform.tfstate`. The object is encrypted client-side (AES-GCM, key from `TF_VAR_tofu_state_passphrase`, which stays in OpenBao). Its envelope keeps `lineage`, `serial` and key-derivation metadata in clear, and a lock object is plain JSON that names `user@host` and the path. Terragrunt writes the generated backend file and the `.terraform` cache under `infra/proxmox/vms/.terragrunt-cache/` (gitignored; no state, but they name the endpoint and bucket). Locking is the s3 backend's native lockfile (`use_lockfile`), verified on this RustFS: a second run while one is active fails with a state-lock error. The unit fails early, naming the variable, when `TF_STATE_S3_ENDPOINT` or `TF_STATE_S3_BUCKET` is empty.

**New Mac.** `just openbao-login`; nothing else is seeded locally. Any Mac that did this and can reach `<endpoint>` can plan, apply, `vm-install` and `vm-deploy` (they read addresses from the state). They fail while the state store is unreachable.

**Provision the state user** (once per RustFS; this section is the only record of these steps outside IaC). The user MUST be named `dotfiles-infra` and the policy `dotfiles-infra-state`: the leak check skips the access key id only because it equals the project name. This repo installs `aws` (`awscli2`) but not `mc`, so run the `mc` lines inside `nix shell nixpkgs#minio-client`.

1. Root credentials into variables, never typed into a command line (bash or zsh). Never `mc alias set`: it writes the root credentials to `~/.mc/config.json`.

   ```bash
   export MC_CONFIG_DIR=$(mktemp -d)        # without this mc creates ~/.mc
   read -r RUSTFS_ROOT_USER                 # the RustFS root credentials are kept with the stack that deploys the RustFS
   read -rs RUSTFS_ROOT_SECRET              # not echoed, not in history
   export MC_HOST_<alias>="http://$RUSTFS_ROOT_USER:$RUSTFS_ROOT_SECRET@<endpoint>:<port>"   # URL-encode special characters
   unset RUSTFS_ROOT_USER RUSTFS_ROOT_SECRET
   ```

2. Save this policy as `policy.json` outside the repo. `DeleteObject` is needed to release the lock. The prefix condition on `ListBucket` denies the backend's workspace-list call, which it ignores on purpose. `GetBucketLocation` only reveals the region and is what `mc` asks for.

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], "Resource": ["arn:aws:s3:::<bucket>/dotfiles-infra/*"]},
       {"Effect": "Allow", "Action": ["s3:ListBucket"], "Resource": ["arn:aws:s3:::<bucket>"], "Condition": {"StringLike": {"s3:prefix": ["dotfiles-infra/*"]}}},
       {"Effect": "Allow", "Action": ["s3:GetBucketLocation"], "Resource": ["arn:aws:s3:::<bucket>"]}
     ]
   }
   ```

3. Create, from the repo root. The secret goes to the vault before it goes to the RustFS, so it cannot be lost. There is exactly one secret here (`$sec`); the root credentials are `RUSTFS_ROOT_*`. `mc admin user add` takes the secret as an argument, so it shows in the process list while it runs, not in shell history (history holds `"$sec"`).

   ```bash
   export SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra"
   mc mb --ignore-existing <alias>/<bucket>         # a fresh RustFS needs the bucket first
   mc admin policy create <alias> dotfiles-infra-state policy.json
   sec=$(openssl rand -hex 24)
   printf '%s' "$sec" | secretspec set AWS_SECRET_ACCESS_KEY
   printf '%s' dotfiles-infra | secretspec set AWS_ACCESS_KEY_ID
   mc admin user add <alias> dotfiles-infra "$sec"  # the secret shows in the process list while this runs, not in shell history (history holds "$sec")
   mc admin policy attach <alias> dotfiles-infra-state --user dotfiles-infra
   unset sec
   printf '%s' 'http://<endpoint>:<port>' | secretspec set TF_STATE_S3_ENDPOINT   # not secrets, but they land in shell history
   printf '%s' '<bucket>' | secretspec set TF_STATE_S3_BUCKET
   ```

4. Verify (a wrong policy shows up here, not in the middle of an apply). The two put/delete lines must succeed and the list outside the prefix must say AccessDenied. Then `just infra-plan` must end without an error.

   ```bash
   secretspec run -- sh -c '
     export AWS_DEFAULT_REGION=us-east-1
     awsr() { aws --endpoint-url "$TF_STATE_S3_ENDPOINT" "$@"; }
     x="s3://$TF_STATE_S3_BUCKET/dotfiles-infra/_probe/x"
     printf x | awsr s3 cp - "$x" && awsr s3 rm "$x"
     awsr s3api list-objects-v2 --bucket "$TF_STATE_S3_BUCKET" --prefix other/
   '
   ```

5. Rotate: same order, vault first. Measured: the old secret is refused at once, so runs fail between the two commands; do not rotate during an apply.

   ```bash
   sec=$(openssl rand -hex 24)
   printf '%s' "$sec" | secretspec set AWS_SECRET_ACCESS_KEY
   mc admin user add <alias> dotfiles-infra "$sec"   # on an existing user this replaces the secret
   unset sec
   ```

6. Remove: detach, remove the user, remove the policy, then delete the four keys from the `dotfiles-infra` OpenBao project. State objects stay in the bucket until you delete them.

   ```bash
   mc admin policy detach <alias> dotfiles-infra-state --user dotfiles-infra
   mc admin user remove <alias> dotfiles-infra
   mc admin policy remove <alias> dotfiles-infra-state
   ```

**Add a VM.** First check that `<ipv4>` and `<mac>` are not used by another host or guest: ping the address and look through the Proxmox guest configs (`/etc/pve/qemu-server/` and `/etc/pve/lxc/` on every node). Then set `TF_VAR_vms`, a JSON map keyed by VM name (a DNS label of 4 to 63 characters that is not a word used elsewhere in this repo; it becomes the hostname). Size: nixos-anywhere's kexec needs at least 1.5 GB of RAM (its `docs/requirements.md`), so use `memory_mb` of at least 2048 (the first VM used 4096 MB and 32 GB of disk). Keep the existing entries and add the new one (the pipe form below does that; the JSON shows the shape):

```json
{
  "<name>": {
    "node": "<node>", "vmid": 0, "mac": "<mac>",
    "ipv4_cidr": "<ipv4>/<prefix>", "gateway": "<gateway>", "dns": ["<resolver>"],
    "cores": 0, "memory_mb": 0, "disk_gb": 0
  }
}
```

```bash
export SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra"
secretspec get TF_VAR_vms | jq -c '. + {"<name>": {"node": "<node>", "vmid": 0, "mac": "<mac>", "ipv4_cidr": "<ipv4>/<prefix>", "gateway": "<gateway>", "dns": ["<resolver>"], "cores": 0, "memory_mb": 0, "disk_gb": 0}}' | secretspec set TF_VAR_vms
just infra-leak-check    # a name that collides with a word in this repo shows up here, before any VM exists
just infra-plan          # must show exactly the new entries
just infra-apply
just vm-install <name>   # wait until the VM has booted; Debian cloud image → NixOS with an encrypted root, via nixos-anywhere
just vm-unlock <name>    # the VM now waits for its disk passphrase in the initrd; this sends it and waits for SSH on port 22
```

`secretspec set` reads the value from stdin when it is piped, so never pass it as an argument (it would land in shell history); pasting multi-line JSON into the interactive prompt is unverified. `SECRETSPEC_REASON` is needed in agent sessions. Names, `vmid`, `mac` and address must be unique across entries; the unit rejects collisions, but only inside `TF_VAR_vms`. `vm-install` refuses unless `debian@<ipv4>` accepts the login, so an installed VM is never reformatted; wait for the VM to boot before running it. It only proves the key is accepted, so the free address and MAC check at the top is yours. Before it formats anything, `vm-install` generates the disk passphrase (first install of that name only) and a fresh initrd SSH host key, and stores both in OpenBao (see **Disk encryption and unlock**).

**Change a role's code.** Edit `hosts/nixos/proxmox-guest/` (both roles share it), `modules/nixos/agent-dev.nix` or `home/linux/` (agent), then `just vm-deploy <name>` (`nixos-rebuild switch` over SSH as root, built on the VM; it prints which configuration the VM gets). A new kernel or initrd takes effect at the next boot, and every boot waits for `just vm-unlock <name>`. `vm-deploy` never rewrites the identity files or the initrd's address: they are written at install.

**Roles: clean or agent.** The optional `role` field of a `TF_VAR_vms` entry picks the NixOS configuration; leaving it out means `clean`. `variables.tf` refuses any other value at plan time, and `vm-install` and `vm-deploy` build `.#proxmox-guest` for `clean` and `.#proxmox-agent` for `agent` (`infra/vm-config.sh`; `just test-roles` evaluates both and fails when the clean guest gains a user, a port or an agent package). A role changes no Proxmox resource: `just infra-plan` shows a flip only as a change to the `vms` output (`role = "clean" -> "agent"`), and the deploy reads the role from the vault, not from the state, so no `infra-apply` has to come first. A deploy prints which configuration the VM gets; re-seeding `TF_VAR_vms` from an older value without the role silently means `clean`, which removes the agent user at the next deploy. Set the role after saving a copy of the map to a private file and checking that the name exists (a mistyped name would add a stub entry): `umask 077; secretspec get TF_VAR_vms > <private file> && jq -e --arg n "<name>" 'has($n)' <private file> >/dev/null && jq -c --arg n "<name>" '.[$n].role = "agent"' <private file> | secretspec set TF_VAR_vms` (same exported environment as above). A different `cores`, `memory_mb` or `disk_gb` is an in-place update of the Proxmox VM (measured: `1 to change`), and the LUKS root does not follow a bigger disk (see **Disk encryption and unlock**), so a resize with a new role is a reinstall: the recipe under **Recovery** (`-replace`, `vm-install`, `vm-unlock`).

- **What `agent` is.** `nixosModules.agent-dev` (options `dotfiles.agent.enable` and `.omp`, `.mise`, `.tern`, `.gh`, `.podman` `.enable`, each on when the agent is; `dotfiles.agent.user`, default `lex`). A login user outside `wheel` with no sudo (root still logs in by key), zsh, and `linger` so that its user services start at boot. Home Manager (`home/linux/agent.nix`, not the Mac's `home/default.nix`): zsh, starship, git with the Mac's identity, direnv with nix-direnv, mise. `programs.nix-ld` so that glibc programs that were not built for NixOS run (mise's runtimes, omp, Tern). omp, `gh`, rootless podman, zram swap, `curl`, `gcc` and `gnumake`. The Home Manager input is `home-manager-nixos` (release-25.11, following `nixpkgs-nixos`): the `home-manager` input is master and does not evaluate against nixos-25.11 (it needs nixpkgs-unstable's `lib/services/lib.nix`). `proxmox-guest` is untouched: its toplevel derivation is byte-identical with and without this module in the flake.
- **Login.** The user logs in with the same keys as root. An activation script copies `/root/.ssh/authorized_keys`, which `vm-install` wrote, to the root-owned `/etc/ssh/agent-authorized-keys` at every activation, and sshd reads that file for every account (`services.openssh.authorizedKeysFiles`). Root's list stays the one list (a key removed there is gone for the user at the next deploy or reboot), root writes nothing inside the user's home, and no key is in the repo or the Nix store. The user's own `~/.ssh/authorized_keys` stays the user's: `tern remote setup` creates it and adds the Mac's Tern device key (which lets that key log in over SSH as the user too), and keys the user adds there stay across deploys and reboots.
- **omp** is pinned by hash in `modules/nixos/agent-dev/omp.nix` (the GitHub release asset of `can1357/oh-my-pi`, version `18.8.6`). It is a Bun-compiled binary, so nothing may strip or patch it; it runs through nix-ld. `omp update` cannot work: it replaces its own binary and the store is read-only. To bump it, change `version` and `hash` together (`nix store prefetch-file --json <release asset URL>` prints the hash; compare it with the digest the release page lists for the asset: `gh release view v<version> --repo can1357/oh-my-pi --json assets`) and `just vm-deploy <name>`. Its config (`home/omp/config.yml`, `models.yml`, `mcp.json`, as committed) is copied into `~/.omp/agent/` as writable files, and so is mise's global config (`~/.config/mise/config.toml`), by `home/linux/writable-copy.sh`: the repo copy replaces the file only when the repo copy is new since the last install (a hash under `~/.local/state/dotfiles/writable-copy/`), and an edit made on the VM is kept as `<name>.dotfiles-backup` then (one previous version). An edit stays across deploys and reboots otherwise (Home Manager activates at every boot). Nix pushes no secret: put `~/.omp/.env` in place by hand (it is deliberately not synced, see **Personal setup** below); the one secret that reaches the VM is the `gh` token that `just vm-sync` writes. The committed omp config was written for the Mac, and these parts cannot work on the VM: the hindsight memory backend and the omniroute, anthropic-refresher and xai-refresher providers (homelab addresses, unreachable from the VM), the `unitllm` provider, and the MCP servers `zennotes`, `open-design` and `unsplash` (Mac paths); `codegraph` is not installed either. Models and roles that name a provider without a credential on the VM fail until you change them.
- **mise.** The global tools are node, python 3, uv, go, rust, bun and `npm:pnpm`, all `latest` (`3` for python), installed on first use (`not_found_auto_install`) or by `mise install`, into `~/.local/share/mise` (outside Nix). The agent role uses nixpkgs-unstable's mise: nixos-25.11's (2025.11.7) takes the free-threaded CPython build for python 3.13 and later and fails with "Python installation is missing a `lib` directory"; 2026.8.6 installs python 3.14. `node.compile` is off because mise compiled node from source by default on this VM and failed on a missing python; the prebuilt node runs through nix-ld (measured: `mise use -g node@lts`, then `node --version`). `mise use -g` works because the global config is a writable file.
- **Tern.** `tern remote setup <user>@<ipv4>`, run on the Mac after the role is deployed, downloads Tern (the VM does it itself) into `~/.local/share/tern`, links `~/.local/bin/tern`, writes the user service `~/.config/systemd/user/tern-remote.service` and starts it; `tern remote doctor <user>@<ipv4>` checks it and the Mac's host list (`~/Library/Application Support/Tern/hosts`) gains `<user>@<ipv4>`. Tern's binary, its state in `~/.config/tern` and that unit are Tern's, not managed by `vm-deploy`; `tern remote update <user>@<ipv4>` updates the binary. The service serves QUIC on **UDP 8376** (measured with `ss`; the Tern service on the Mac listens on 8377 because it is told to) and the firewall opens exactly that, only with `dotfiles.agent.tern.enable`. A drop-in the module installs (`tern-remote.service.d/10-direct-lan.conf`) starts it with `--relay none --pkarr none --no-iroh`: it never contacts iroh.stencil.so or a relay, and only a Mac with a UDP path to the VM reaches it (measured: the service opens no other UDP port). Deploy before `tern remote setup`: a service that started without the drop-in connected to the iroh relay and published an endpoint id, and its first setup added the host to the Mac's list by endpoint id (`<user>@<endpoint id>`); after the drop-in and a restart, `tern remote setup` again adds `<user>@<ipv4>`, and the endpoint-id line is then stale and can go from the hosts file. Without a UDP path from the Mac to the VM (another network, no VPN) the Mac cannot reach it: before the drop-in, setup fell back to iroh; with it, nothing does, and turning relay or iroh back on is a deliberate change that this module does not make.
- **Limits to know.** The Tern drop-in repeats Tern 0.6.0's own `ExecStart` (`~/.local/share/tern/build/tern remote serve --user --state-dir ~/.config/tern`) with the three flags added: if a `tern remote update` changes that command, change the drop-in too. A running service takes a changed drop-in only after `systemctl --user restart tern-remote.service` or a reboot; check with `ps -u <user> -o args=` that its line holds `--no-iroh`. mise's tools float (`latest`, installed on first use), unlike omp, which is pinned by hash; `mise use -g <tool>@<version>` pins one.
- **Podman and zram.** `virtualisation.podman` is rootless (the user has subuid and subgid ranges, the `newuidmap` wrappers come with NixOS); `podman run --rm docker.io/library/hello-world` works as the user. `zramSwap` is on.
- **Clean to agent:** set `role` to `agent`, `just vm-deploy <name>` (the first deploy builds the module on the VM and fetches omp, about 270 MB), then `tern remote setup` if you want Tern.
- **Agent to clean:** set `role` to `clean`, `just vm-deploy <name>`. NixOS removes what the module declares: the services, the packages, the firewall port, zram, the user's entry in the account database and its subuid range. Measured leftovers: the home directory stays, with everything in it (`~/.ssh/authorized_keys` and any key you added there, Tern's binary and state, omp's config, mise's installed tools, podman's images, Home Manager's links, which dangle after a garbage collection); the user's uid stays reserved, so the user comes back with the same uid and finds its home; `/lib64/ld-linux-x86-64.so.2` stays as a link into the store (it is a tmpfiles link, harmless); Tern's service and the user's manager keep running as the removed user until `systemctl stop user@<uid>.service` or the next boot (the firewall has closed the port at once, and nothing restarts them after a reboot). Flipping back to `agent` works: the user, linger, the services and Tern's service return, and the Mac's host entry works again without a new setup. A truly clean VM needs a reinstall with role `clean`.
- **Personal setup: gh, Hindsight, plugins, skills.** Options `dotfiles.agent.sync.gh`, `.hindsight`, `.plugins` and `.skills`, each on when the agent is; the VM lists them in `/etc/dotfiles-agent-sync.json`, which `just vm-sync <name>` reads. `just vm-deploy <name>` runs `vm-sync` after an agent deploy; when that sync fails or is refused, the deploy has still happened and exits 1 (fix the cause, then `just vm-sync <name>`). `~/.omp/.env` is **not** synced, in any form: it holds the API keys, so put it in place by hand. `just vm-sync` itself runs on the Mac and is for the agent role only; everything it runs on the VM is the agent user's (`infra/vm-sync-remote.sh`, sent over ssh), never root's.
  - **Host keys.** Every connection of `vm-sync` (ssh and rsync) uses `StrictHostKeyChecking=yes` and `UpdateHostKeys=no`: the VM's key must already be pinned in `~/.ssh/known_hosts`, or `vm-sync` refuses before it sends anything and says so, naming the re-key step of **Recovery** (`ssh-keygen -R <ipv4>`, then connect once and compare the fingerprint, or `just vm-deploy <name>`, which trusts a key on first use as it always did). `vm-install` is unchanged. `vm-deploy` takes the answer before its switch (the switch itself may pin a new key): an agent deploy over a key that was not pinned before it still deploys, does not sync, and exits 1 with that message; a clean deploy over an unpinned key skips the removal below (nothing was synced from this Mac), and a key that does not match stops it before anything is changed.
  - **gh.** Home Manager sets `gh auth git-credential` as git's credential helper for `github.com` and `gist.github.com`. The login is one dedicated fine-grained token per VM, stored by you in the `dotfiles-infra` OpenBao project as the JSON map `VM_GH_TOKENS` (VM name to token; optional, the manifest default is `{}`, so every other recipe works without it). Store one without the token reaching a command line or the shell history, with the same exported `SECRETSPEC_FILE` and `SECRETSPEC_REASON` as above: `read -rs tok; secretspec get VM_GH_TOKENS | TOK=$tok jq -c --arg n <name> '. + {($n): env.TOK}' | secretspec set VM_GH_TOKENS; unset tok` (remove an entry with `del(.[$n])`). `vm-sync` writes `~/.config/gh/hosts.yml` of the agent user (mode 600, owner the user, over ssh stdin; the token must be one line of 20 to 255 letters, digits or underscores) only when the map has an entry for that VM; with none it prints `vm-sync: gh: no token for <name> in VM_GH_TOKENS: skipped` and goes on. A `hosts.yml` you made on the VM with `gh auth login` is kept as `hosts.yml.dotfiles-backup` and put back by the removal below. `just infra-leak-check` scans the tracked files for every token in the map.
  - **Plugins.** `just omp-plugins-capture` (on the Mac) copies `package.json`, `bun.lock` and `omp-plugins.lock.json` from `~/.omp/plugins` to `home/omp/plugins/` (`home/omp/plugins-capture.sh`). It writes nothing and exits 1 when a file holds a token, a URL, an absolute path, a local or git source (`file:`, `link:`, `workspace:`, `github:`, `git+...`) or a registry other than the default, since the files are public and the VM has no `.npmrc`. It drops lock entries of plugins that are not dependencies (stale), and sets each lock version to the one installed on disk (otherwise `omp plugin doctor` reports lock drift as an error). `node_modules` is never copied: it holds the Mac's native binaries, and `bun install` resolves the Linux ones from `bun.lock`. The three files are placed in `~/.omp/plugins` as writable files (omp rewrites them; same rules as the omp config above), and the user service `omp-plugins-install` runs `bun install --frozen-lockfile` there when their hash is new (stamp `~/.local/state/dotfiles/omp-plugins.stamp`, written only after a successful install, so a failure is retried: up to 5 times an hour, and at the next boot). It is `Type=simple`, so a deploy does not wait for the first install (about a gigabyte): follow it with `journalctl --user -u omp-plugins-install`. bun's download cache lives in `~/.omp/plugins/.bun-cache` and is removed after each run. bun, node and `harper-cli` (which `pi-harper-grammar` runs) come from nixpkgs-unstable: nixos-25.11's `harper` builds `harper-ls` only. Plugins installed by hand on the VM (`omp plugin install`) change `package.json` there and stay until a new capture replaces it (the old file is kept as `.dotfiles-backup`).
  - **Skills.** `vm-sync` mirrors every directory of `~/.skills-manager/skills` that holds a `SKILL.md` (not hidden, not a link) into `~/.omp/agent/skills` with rsync, one directory at a time, exactly inside it (`--delete` there and nowhere else). Nothing else in `~/.omp/agent/skills` is touched or deleted. `~/.omp/agent/managed-skills` (the auto-learned store, with infra notes) is never read, copied or listed: a source path or a library member that resolves to a `managed-skills` path is refused. No skill is in this repo.
  - **Hindsight.** The LAN address in the committed omp config cannot be reached from the VM; the public Hindsight API sits behind an API-key gate instead (header `Authorization: Bearer <key>`: 200 with a good key, 401 with none or a wrong one). omp reads `HINDSIGHT_API_URL` and `HINDSIGHT_API_TOKEN` from the environment before `config.yml` (measured on the VM with omp 18.8.6 against a fake server: the URL and key of the environment won over `hindsight.apiUrl`), so the sync sets those two variables and touches neither `~/.omp/.env` nor `config.yml`. One entry per VM, one key per VM (so that it can be revoked alone), stored by you in the `dotfiles-infra` project as the JSON map `VM_HINDSIGHT` (VM name to `{"url": "https://…", "token": "…"}`; optional, the manifest default is `{}`). Store one without the key reaching a command line or the shell history: `read -rs key; secretspec get VM_HINDSIGHT | KEY=$key U=<url> jq -c --arg n <name> '. + {($n): {url: env.U, token: env.KEY}}' | secretspec set VM_HINDSIGHT; unset key` (the pipe keeps the old map off the terminal; never run `secretspec get` with its output on the terminal). What `vm-sync` does: first, on the Mac, `infra/vm-hindsight-health.py` sends `GET <url>/health` with the key (verified TLS, no proxy, no redirect followed, URL and key on stdin only): anything but 200 stops the sync with a message and writes nothing for this piece (a file that is already there stays as it was). Then it writes `~/.config/dotfiles/hindsight.env` for the agent user (mode 600, its directory 700; the URL and the key as two `NAME='value'` lines under a comment that says vm-sync wrote it) over ssh stdin, and the `.zshenv` of Home Manager exports both (`set -a`) in every zsh: the ssh login shell, `ssh host command` and Tern sessions. A process that is not started by zsh (a systemd user unit) does not see them. No entry for the VM: the file is removed and `vm-sync` prints one line (`hindsight: no entry for <name> in VM_HINDSIGHT, removed …`); a file of that name that vm-sync did not write is left alone. The flip to clean removes the file.
  - **Revoking or rotating a VM's Hindsight key.** The same key lives in two OpenBao places: the property of that client in `secret/apps/hindsight-api-keys` (an ExternalSecret copies it into the cluster about every minute, then Envoy takes a few seconds) and the VM's entry in `VM_HINDSIGHT`. Revoke: (1) `bao kv metadata get -mount=secret apps/hindsight-api-keys`, find the newest version `<V0>` that does not hold the VM's property and with no other property added after it; (2) `bao kv rollback -mount=secret -version=<V0> apps/hindsight-api-keys` (never `bao kv put` with a partial set; if another client's key was added after `<V0>` the rollback would delete it, so read the set into a mode-600 file, drop the one property and put the rest back from the file, which is untested); (3) wait up to a minute and a few seconds, then `GET /health` with the old key must be 401 while the other clients' keys still give 200; (4) optionally `bao kv destroy -mount=secret -versions=<versions that held it> apps/hindsight-api-keys`; (5) remove or replace the VM's entry in `VM_HINDSIGHT` (the next `vm-sync` then removes the file, or writes the new key after its health check). Mint a key: `openssl rand -hex 24` into a mode-600 file, then `bao kv patch -mount=secret apps/hindsight-api-keys <client>=-` from stdin (patch, never put). Rotate: add the new property, update `VM_HINDSIGHT`, `just vm-sync <name>`, then revoke the old property as above (the gate must answer 401 for it).
  - **Hindsight, residual risks.** The key is in the environment of every shell and process of the agent user and in a mode-600 file: anything that runs as that user can read it (so can its other processes through `/proc`). The gate does not name the client in its access log, and nothing here verifies per-key scoping inside Hindsight: assume every key has the same access. Cloudflare's 100 second limit can cut a long reflect call. With per-project tagged scoping, the VM's projects can be tagged differently from the Mac's paths, so memories from the VM land under other tags.
  - **Flip to clean.** Before the switch, `vm-deploy` runs the removal as the agent user: exactly what the sync placed goes (the files and skill directories the sync recorded in `~/.local/state/dotfiles/vm-sync/manifest`, including the Hindsight file; the plugin install `~/.omp/plugins` as one directory with its install stamp and the records of its three files), a displaced `hosts.yml` comes back, and directories the sync made are removed while empty. If the removal fails, the deploy stops before the role changes. Nothing else in the home changes (omp's config, `~/.omp/.env`, anything you made); a plugin you installed by hand into `~/.omp/plugins` goes with that directory. Flipping back to `agent` places everything again (the plugin install downloads again).

**Identity: fixed at install.** NixOS runs no cloud-init (the module is off and the package is not in the system closure), so nothing on a cloud-init drive (user data, scripts, boothooks, part handlers) can act on the VM; the Proxmox drive only serves the Debian bootstrap stage. `vm-install` writes the identity into the new system from the VM's `TF_VAR_vms` entry, after checking each value (they end up inside a unit file): `/etc/hostname` (the name), `/etc/systemd/network/10-static.network` (`[Match] MACAddress=<mac>`, so the NIC's name does not matter; `[Network]` `Address=<ipv4>/<prefix>`, `Gateway=<gateway>`, one `DNS=<resolver>` per entry of `dns`) and, for the initrd, `/etc/secrets/initrd/10-initrd.network`. NixOS leaves the first two alone: the role sets no `hostName` (do not set one: NixOS would replace `/etc/hostname` with a symlink) and defines no networkd unit. What follows from it:

- Changing `ipv4_cidr`, `gateway` or `dns` in `TF_VAR_vms`, or `ipconfig0`, `nameserver` or `sshkeys` on the Proxmox VM, does not change the running VM, also not across a reboot. The drive stays attached and OpenTofu keeps maintaining it for the Debian stage; NixOS never reads it. Measured: a throwaway key set as `sshkeys` and a different unused `ipconfig0` reached the drive and had no effect on the guest. `mac` is different: it is the NIC's hardware address (`network_device`), and both network files match on it, so applying a new one should leave the next boot without network, not even in the initrd (expected from the match; not measured). Reinstall for a MAC change, or put the new `MACAddress=` into both files (steps 1 and 2 below) before you apply it; that variant was not exercised.
- There is no search domain. A search domain that the Proxmox host's resolver settings put on the drive is not carried over (it never came from the VM entry); names resolve with their full domain.
- To change the address, gateway or resolver, in this order (the VM stays reachable at its old address until step 3; `vm-deploy` and `vm-unlock` read the address from the OpenTofu state, which follows `TF_VAR_vms` only after `just infra-apply`): 1. As root over SSH, edit the `Address=`, `Gateway=` and `DNS=` lines of `/etc/systemd/network/10-static.network` and `/etc/secrets/initrd/10-initrd.network`; keep mode 0644. 2. `just vm-deploy <name>`: it rewrites the initrd from the edited initrd file; nothing reloads networkd, so the running address does not change. 3. `reboot` on the VM. 4. Change the entry in `TF_VAR_vms`, then `just infra-plan` and `just infra-apply` (only the drive changes; the provider may reboot the VM, which then waits in the initrd). 5. `just vm-unlock <name>`. If the VM is not reachable afterwards, type the passphrase on the serial console and see **Recovery**. This sequence was not exercised as a whole; the two files and the reboot and unlock path were.
- To change the name, reinstall: the entry's key is the Proxmox VM name, the hostname and the key of both vault maps, and OpenTofu replaces the VM when the key changes (**Remove a VM**, then **Add a VM** with the new name; the new name gets a new disk passphrase). Editing `/etc/hostname` alone renames only the guest and leaves it out of step with its entry.
- A VM installed with an earlier version of this role (cloud-init on NixOS) must be reinstalled before `vm-deploy` of the current role: it has no `10-static.network` (its network came from cloud-init, which the current role removes), so it would come up without network at the next reboot. If you do not want to reinstall, write `/etc/hostname` and `/etc/systemd/network/10-static.network` by hand first, with the content described above, and mind that the initrd file (`/etc/secrets/initrd/10-initrd.network`) already exists from that install.

**Disk encryption and unlock.** The disk has a BIOS boot partition, an unencrypted 1 GiB ext4 `/boot` (kernel, initrd, initrd secrets; GRUB on SeaBIOS never touches LUKS) and a LUKS2 root (`cryptroot`, `aes-xts-plain64`; TRIM is not passed through, because it would show which blocks are free). GRUB keeps 5 generations so `/boot` cannot fill up.

- Secrets: `VM_LUKS_KEYS` maps `<name>` to a generated 64-hex-digit passphrase. `vm-install` creates it on the first install of a name and keeps it across reinstalls; it writes it to OpenBao before the disk is touched and passes it to the installer as a file in a 0700 temp directory (`nixos-anywhere --disk-encryption-keys`). `VM_INITRD_HOST_KEYS` maps `<name>` to the public key of the initrd's SSH host key; every install makes a fresh key pair and stores the public half first. Both maps are updated by read-modify-write, and the entries are checked again right before the disk is formatted, but run one `vm-install` at a time: two at once can overwrite each other's entry.
- What the initrd gets: the initrd runs systemd with networkd and an SSH server on port 2222. Its static address, its SSH host key and its authorized keys are not in the repo or the Nix store. `vm-install` places them on the new system (`nixos-anywhere --extra-files`): `/etc/secrets/initrd/10-initrd.network` (MAC, address and gateway of the VM entry), `/etc/secrets/initrd/ssh_host_ed25519_key`, and `/root/.ssh/authorized_keys` (the key list from `TF_VAR_ssh_authorized_keys`, also root's key list in stage 2). The bootloader step (`boot.initrd.secrets`) copies them into the initrd, which sits on the unencrypted `/boot`. The initrd's address is cleared before switch-root, so stage 2 configures the NIC from scratch from its own file.
- Every boot waits: after `vm-install`, a reboot, or a restart of the Proxmox host (`on_boot`), the VM stops in the initrd until the passphrase arrives. Nothing unlocks it unattended, by design. `just vm-unlock <name>` connects to port 2222 with the pinned host key (a throwaway `known_hosts`, strict checking; a mismatch aborts and is never retried), finds the pending passphrase query and answers it with `systemd-reply-password`. The passphrase goes over a pipe (not argv, no tty, nothing echoed). It retries for up to `VM_UNLOCK_TIMEOUT` seconds (default 300) while no query is pending, then waits up to `VM_UNLOCK_BOOT_TIMEOUT` seconds (default 120) for port 22. If port 2222 is still open 45 s after the answer, the initrd asked again: the passphrase was refused. It exits at once, with nothing sent, when the VM already answers on port 22 and not on 2222.
- Console fallback: `qm terminal <vmid>` on `<node>` shows the prompt `Please enter passphrase for disk cryptroot:`. Type the passphrase there (read it with `secretspec get VM_LUKS_KEYS | jq -r '.["<name>"]'` in a terminal you trust). An empty Enter counts as one of the three tries. Root has no password, so the console cannot log in. This works when the initrd's network does not, for example after the VM's address changed.
- The initrd's address is the third identity file (see **Identity: fixed at install**): it is written at install and neither `vm-deploy` nor a change of `TF_VAR_vms` touches it.
- Sizing: LUKS2 derives the key with Argon2id, and cryptsetup peaked at 1 GiB of memory at unlock (measured on a 4096 MB VM). Keep `memory_mb` at 2048 or more, as the installer already needs. A larger `disk_gb` later enlarges the virtual disk only: NixOS runs no growpart or resizefs (there is no cloud-init), and the root is a LUKS partition anyway. The manual way is `growpart /dev/sda 3`, `cryptsetup resize cryptroot` and `resize2fs /dev/mapper/cryptroot` on the VM; it was not exercised.
- Limits, so nobody over-reads this: it protects the data on the disk image, its snapshots and backups. It does not protect against someone who can change `/boot` (they can replace the initrd with one that records the passphrase you type, and the initrd's SSH host key is readable there), against a hypervisor administrator who can read the VM's memory or attach boot media, or against losing OpenBao: the passphrase is the only way to unlock, so no OpenBao copy means no data. The user-data path is closed: NixOS runs no cloud-init, so nothing a Proxmox user can put on the cloud-init drive (a custom `cicustom` snippet included) can run at boot.

**Remove a VM.** Remove its key with `secretspec get TF_VAR_vms | jq -c 'del(.["<name>"])' | secretspec set TF_VAR_vms` (same exported environment as above), `just infra-plan` (must show exactly that VM's destroy), `just infra-apply`. Then delete its entries from the two maps the same way (`secretspec get VM_LUKS_KEYS | jq -c 'del(.["<name>"])' | secretspec set VM_LUKS_KEYS`, and `VM_INITRD_HOST_KEYS`); the passphrase of a destroyed disk is useless. Removing the last VM on a node also destroys that node's downloaded Debian image. Renaming a key is a destroy plus a create: the name is the `for_each` key and the hostname.

**Rotate the Proxmox API token.** Create the new token in Proxmox, copy the full `user@realm!id=secret` string to the clipboard, then `pbpaste | secretspec set TF_VAR_proxmox_api_token` (same exported environment). Without this the next plan fails with 401.

**Recovery.**

- Unreachable after boot: serial console, `qm terminal <vmid>` on `<node>`. If the VM sits at `Please enter passphrase`, run `just vm-unlock <name>`, or type the passphrase there. At the GRUB menu (serial too) pick an older generation to roll back a kernel or role problem, then fix the role and `just vm-deploy <name>`. That does not help with the identity files (next bullet).
- Stage 2 has no network after a NIC or MAC change, or the identity files are wrong: the initrd still answers if its own file is right and the console prompt always works, but root cannot log in on the console. GRUB's older generations do not help, because `/etc/hostname` and `/etc/systemd/network/10-static.network` belong to no generation, and no generation has cloud-init to bring the network back (it is not installed on NixOS). So: reinstall (next bullet), or boot a rescue image from Proxmox (attach an ISO, boot it), open the volume (`cryptsetup open /dev/disk/by-partlabel/disk-main-root cryptroot`, with the passphrase), mount it, fix the two files (mode 0644), unmount, close and boot again. The rescue path was not exercised.
- `vm-unlock` stops with a host key error: the initrd at that address does not present the key `vm-install` pinned. It never retries. Check that the address belongs to `<name>`, then use the console. A reinstall pins a new key.
- Reinstall: recreate the VM, clear its old host key, wait for Debian to boot, then install again and unlock. The recreated Debian has a new host key; without `ssh-keygen -R`, the `vm-install` guard refuses the changed key (its message names this cause, next to "still booting" and "already NixOS"). The disk passphrase of `<name>` is kept; the initrd host key is new.

  ```bash
  just infra-apply "-replace='proxmox_virtual_environment_vm.vm[\"<name>\"]'"
  ssh-keygen -R <ipv4>
  just vm-install <name>
  just vm-unlock <name>
  ```

- Kexec failed while the VM still runs Debian: rerun `just vm-install <name>`.
- **State store unreachable before a run starts:** plan, apply, `vm-install` and `vm-deploy` fail before they change anything. `vm-ip` says it could not read the VM list from the state (ignore any "no VM named" text from older versions). Retry when it is back.
- **State store dropped during an apply** (reboot, network): OpenTofu cannot save the new state. It writes it, encrypted, to `errored.tfstate` in its working directory, `infra/proxmox/vms/.terragrunt-cache/<hash>/<hash>/` (find it with `find infra/proxmox/vms/.terragrunt-cache -name errored.tfstate`), and the lock object stays. Do NOT rerun the apply (it plans the same VMs again) and do NOT delete `.terragrunt-cache`. When the store is back: force-unlock (next bullet), copy `errored.tfstate` out (`cp -p`, keep mode 600), upload it as the state object (restore bullet), then `just infra-plan` must show no changes for what was applied. `tofu state push` does not work here: it refuses an encrypted file.
- **Stale lock:** a crashed run can leave the lock object `dotfiles-infra/proxmox-vms/terraform.tfstate.tflock`. Only when no run is active (the id is in the lock error):

  ```bash
  cd infra/proxmox/vms && SECRETSPEC_FILE=../../secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- terragrunt force-unlock <id>
  ```

- **Back up the state object** (before applies that replace or destroy a VM; a timestamped name keeps the last good copy). Copy the object as is, to a private path outside the repo. Never `tofu state pull` into a file: that is decrypted plaintext.

  ```bash
  SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- sh -c 'umask 077; aws --region us-east-1 --endpoint-url "$TF_STATE_S3_ENDPOINT" s3 cp "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate" "$HOME/infra-state-$(date +%Y%m%dT%H%M%S).backup"'
  ```

- **Restore the state object** (no run active; after a lost or damaged object, or after an outage during an apply): upload the encrypted file as is, then plan.

  ```bash
  SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- sh -c 'aws --region us-east-1 --endpoint-url "$TF_STATE_S3_ENDPOINT" s3 cp <file> "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate"'
  just infra-plan
  ```

  `just infra-plan` must show no changes for what the file holds. What was applied after a backup shows as to-create: import it before any apply, then read what the plan still wants to change. This path was not exercised:

  ```bash
  cd infra/proxmox/vms && SECRETSPEC_FILE=../../secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- terragrunt import 'proxmox_virtual_environment_vm.vm["<name>"]' <node>/<vmid>
  # and per node: terragrunt import 'proxmox_download_file.debian["<node>"]' <node>/<datastore>:import/<file name>
  ```

  (ids as in the bpg/proxmox 0.112 docs). The passphrase must be the one the file was written with.
- **The object no longer decrypts** (the passphrase in OpenBao was lost or changed, or the object is damaged): every command fails with a decrypt error, `import` included. Move the object aside first (same `secretspec run -- sh -c '…'` form, with `s3 mv "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate" "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate.unreadable"`), then restore a backup made with the right passphrase, or import. The passphrase lives only in OpenBao, so losing it makes every backup unreadable too.

**Before every commit that touches `infra/`:** `just infra-leak-check` (expects `no leaks`; reads OpenBao, scans tracked files for the real values). `just test-infra` tests the check itself.

## New machine

1. Install Nix (Determinate), Xcode CLT, clone this repo to `~/.dotfiles` (fixed path: OMP and OmniWM config are live symlinks into this checkout).
2. `curl -sSL https://install.secretspec.dev | sh`
3. `just openbao-login`
4. First activation (nix-darwin not on PATH yet):

   ```bash
   nix run nix-darwin -- switch --flake .#<hostname>
   ```

   `<hostname>` is the `hosts` key for this Mac; the switch renames the Mac to it, so afterwards plain `just switch` / `just home` find it.
5. `mise install` (language runtimes are mise, not nix packages).

Activation will refuse if OpenBao is unreachable or a declared secret is missing.

Atuin sync logs itself in during that activation (`atuinLogin`); no manual `atuin login`.

## New host

1. Add the Mac to `hosts` in `flake.nix`, keyed by the hostname you want it to have:

   ```nix
   <hostname> = {username = "<id -un on that Mac>";};
   ```

   Add `homeDirectory = "/Users/<folder>";` only if the home folder name differs from the username. Any `profiles`/`system` set there override the defaults.
2. Optional: `cp -r hosts/_template hosts/<hostname>` for host-only settings (display mode, extra packages).
3. First activation as in **New machine** step 4; `just switch` afterwards.

`just home` builds the Home Manager config of the user running it (`id -un`), not of a user named after the host.

## Shell

- zsh + Starship. Completions are cached after `compinit` (do not `source <(tool completion zsh)` on every start).
- **Ctrl-R**: `atuin-fzf-widget` — Atuin's synced DB piped through real [fzf](https://github.com/junegunn/fzf) (`--scheme=history`). Enter fills the prompt; it does not run the command. Atuin is told `--disable-ctrl-r` so it never binds the key.
- **Ctrl-T** / **Alt-C**: fzf file / directory widgets (`programs.fzf.historyWidget.command` is empty on purpose).
- Native Atuin TUI: `atuin search -i`.
- Atuin config: `programs.atuin.settings` in `home/default.nix`. `config.toml` is a read-only store symlink, so `/model`, `atuin setup` and `atuin config set` can't save; change settings in nix. The AI token is not in it: secretspec `ATUIN_AI_TOKEN` → `~/.config/atuin/ai-token`, exported as `ATUIN_AI__API_TOKEN` by zsh/bash shells that have a TTY (a token in `settings` would override it). New shells pick it up; `exec zsh` after it changes.
- To give Ctrl-R back to Atuin: drop `"--disable-ctrl-r"` from `programs.atuin.flags` and delete the `atuin-fzf-widget` `mkOrder 2000` block in `home/default.nix`, then `just home` and `exec zsh`.

## Homebrew

Taps are flake inputs (`flake = false`), registered in `nix-homebrew.taps` (`lib/builders.nix`). Adding a third-party formula/cask is that plus `homebrew.brews` / `homebrew.casks`, then `nix flake lock` and `just switch` (not `just home`). Tap trust is automatic: `profiles/personal.nix` marks every non-`homebrew/` tap `trusted` in the Brewfile, which is the only trust that survives activation (`brew bundle --force-cleanup` rewrites `~/.homebrew/trust.json` from the Brewfile).

`homebrew.onActivation.upgrade = false` so `just switch` stays offline-ish. `just update` only moves the lockfile; the taps under `/opt/homebrew/Library/Taps` are synced from it by `just switch`, and upgrading against stale taps fails for formulae with moving download URLs (lightpanda's `nightly` asset). `just brew-upgrade` therefore switches first whenever the lock is newer than the active system; `just update-all` is the explicit one-shot.

## Herdr

`herdr` is mise (`herdr = "latest"` in `home/default.nix`), not a nix package. **herdr-plus** is a herdr plugin, not a Homebrew tap — the tap only installs a PATH binary and does not register actions. `home.activation.herdrPlusPlugin` runs `herdr plugin install cloudmanic/herdr-plus --yes` when `plugins.json` does not already list it. Config: `home/herdr/config.toml` (prefix+o projects, prefix+y quick-actions) and `home/herdr/quick-actions/`.

herdr has no screen detection for omp: omp's working/idle/blocked state comes only from herdr's omp extension (`~/.omp/agent/extensions/herdr-omp-agent-state.ts`). Without it every omp pane reads idle in the sidebar and `resume_agents_on_restore` cannot resume omp. `home.activation.herdrOmpIntegration` runs `herdr integration install omp` unless `herdr integration status` already reports it current. Running omp sessions only load it after a restart.

## OmniWM

OmniWM opens its command palette on ⌃⌥Space. macOS ships the same chord as "Select next source in Input menu", so both fire and OmniWM's Health page warns. `home.activation.omniwmPaletteChord` turns the macOS shortcut off (symbolic hotkey 61) with `defaults write -dict-add`, which leaves every other system shortcut as it is, then applies it with `activateSettings -u` so no logout is needed.

## Notes

- `docs/SETUP.md` is a stub. This README is the setup path.
- `just docs` / `just docs-serve` expect an mdbook tree that is not present.
- Formatter is **alejandra** (`just fmt`), not nixfmt.
- Lint baseline: [docs/EXEMPTIONS.md](docs/EXEMPTIONS.md).
