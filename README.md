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
infra/                    Proxmox VMs: Terragrunt unit, secretspec manifest (names only), leak check
hosts/nixos/              generic NixOS guest role (proxmox-guest)
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

NixOS guests on Proxmox, provisioned with Terragrunt + OpenTofu (`bpg/proxmox`) and installed with `nixos-anywhere`. One generic role (`hosts/nixos/proxmox-guest`); hostname and network come from the cloud-init drive, not from the repo, and root's SSH keys are placed once by `vm-install`. The root disk is LUKS2 and every boot waits for its passphrase (see **Disk encryption and unlock**). Root login by key only, no Home Manager on the VM, no per-VM roles, and no QEMU guest agent: the VM has no command channel from Proxmox into the guest, and cloud-init runs only its hostname, DNS, growpart and resizefs modules (no commands, files, users, passwords or SSH keys).

**What lives where.** The repo holds no server value, not even in docs or comments. `just infra-leak-check` catches the Proxmox endpoint host, token id and secret, state passphrase, the S3 endpoint host, the S3 secret key, every VM LUKS passphrase, and every VM name, IPv4, MAC and gateway, in tracked file contents. It does not catch the S3 access key id (it equals the project name), the bucket, node, datastore and bridge names, vmids, sizing, DNS resolvers, the initrd host public keys (public by design), tracked path names, commit messages or git history; those stay with the author. Placeholders below: `<endpoint>`, `<bucket>`, `<name>`, `<ipv4>`, `<vmid>`, `<node>`.

- Repo: `infra/` (Terragrunt unit `infra/proxmox/vms`, `infra/root.hcl`, `infra/secretspec.toml` = key *names* only) and `hosts/nixos/proxmox-guest/`.
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

**Change the role.** Edit `hosts/nixos/proxmox-guest/`, then `just vm-deploy <name>` (`nixos-rebuild switch` over SSH as root, built on the VM). A new kernel or initrd takes effect at the next boot, and every boot waits for `just vm-unlock <name>`. The initrd's address (below) is written at install and not by `vm-deploy`.

**Disk encryption and unlock.** The disk has a BIOS boot partition, an unencrypted 1 GiB ext4 `/boot` (kernel, initrd, initrd secrets; GRUB on SeaBIOS never touches LUKS) and a LUKS2 root (`cryptroot`, `aes-xts-plain64`; TRIM is not passed through, because it would show which blocks are free). GRUB keeps 5 generations so `/boot` cannot fill up.

- Secrets: `VM_LUKS_KEYS` maps `<name>` to a generated 64-hex-digit passphrase. `vm-install` creates it on the first install of a name and keeps it across reinstalls; it writes it to OpenBao before the disk is touched and passes it to the installer as a file in a 0700 temp directory (`nixos-anywhere --disk-encryption-keys`). `VM_INITRD_HOST_KEYS` maps `<name>` to the public key of the initrd's SSH host key; every install makes a fresh key pair and stores the public half first.
- What the initrd gets: the initrd runs systemd with networkd and an SSH server on port 2222. Its static address, its SSH host key and its authorized keys are not in the repo or the Nix store. `vm-install` places them on the new system (`nixos-anywhere --extra-files`): `/etc/secrets/initrd/10-initrd.network` (MAC, address and gateway of the VM entry), `/etc/secrets/initrd/ssh_host_ed25519_key`, and `/root/.ssh/authorized_keys` (the key list from `TF_VAR_ssh_authorized_keys`, also root's key list in stage 2). The bootloader step (`boot.initrd.secrets`) copies them into the initrd, which sits on the unencrypted `/boot`. The initrd's address is cleared before switch-root, so stage 2 takes its network from cloud-init as before.
- Every boot waits: after `vm-install`, a reboot, or a restart of the Proxmox host (`on_boot`), the VM stops in the initrd until the passphrase arrives. Nothing unlocks it unattended, by design. `just vm-unlock <name>` connects to port 2222 with the pinned host key (a throwaway `known_hosts`, strict checking; a mismatch aborts and is never retried), finds the pending passphrase query and answers it with `systemd-reply-password`. The passphrase goes over a pipe (not argv, no tty, nothing echoed). It retries for up to `VM_UNLOCK_TIMEOUT` seconds (default 300), then waits for port 22.
- Console fallback: `qm terminal <vmid>` on `<node>` shows the prompt `Please enter passphrase for disk cryptroot:`. Type the passphrase there (read it with `secretspec get VM_LUKS_KEYS | jq -r '.["<name>"]'` in a terminal you trust). An empty Enter counts as one of the three tries. Root has no password, so the console cannot log in. This works when the initrd's network does not, for example after the VM's address changed.
- The initrd's address is fixed at install. When `ipv4_cidr`, `mac` or `gateway` of the VM entry changes, the initrd keeps the old values: unlock on the console, edit `/etc/secrets/initrd/10-initrd.network` on the VM (`[Match]` `MACAddress=<mac>`, `[Network]` `Address=<ipv4>/<prefix>` and `Gateway=<gateway>`, mode 0644, because networkd reads it as an unprivileged user) and run `just vm-deploy <name>` to rewrite the initrd.
- Limits, so nobody over-reads this: it protects the data on the disk image, its snapshots and backups. It does not protect against someone who can change `/boot` (they can replace the initrd with one that records the passphrase you type, and the initrd's SSH host key is readable there), against a hypervisor administrator who can read the VM's memory, or against losing OpenBao: the passphrase is the only way to unlock, so no OpenBao copy means no data. cloud-init still runs part handlers from user data (`#cloud-boothook`, `#part-handler`) before its module lists apply: the stock Proxmox user data is plain `#cloud-config`, but anyone who can set a custom user-data snippet on the VM can still run code during boot.

**Remove a VM.** Remove its key with `secretspec get TF_VAR_vms | jq -c 'del(.["<name>"])' | secretspec set TF_VAR_vms` (same exported environment as above), `just infra-plan` (must show exactly that VM's destroy), `just infra-apply`. Then delete its entries from the two maps the same way (`secretspec get VM_LUKS_KEYS | jq -c 'del(.["<name>"])' | secretspec set VM_LUKS_KEYS`, and `VM_INITRD_HOST_KEYS`); the passphrase of a destroyed disk is useless. Removing the last VM on a node also destroys that node's downloaded Debian image. Renaming a key is a destroy plus a create: the name is the `for_each` key and the hostname.

**Rotate the Proxmox API token.** Create the new token in Proxmox, copy the full `user@realm!id=secret` string to the clipboard, then `pbpaste | secretspec set TF_VAR_proxmox_api_token` (same exported environment). Without this the next plan fails with 401.

**Recovery.**

- Unreachable after boot: serial console, `qm terminal <vmid>` on `<node>`. If the VM sits at `Please enter passphrase`, run `just vm-unlock <name>`, or type the passphrase there. At the GRUB menu (serial too) pick an older generation to roll back, then fix the role and `just vm-deploy <name>`.
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
