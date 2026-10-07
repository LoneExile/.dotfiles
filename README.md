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

NixOS guests on Proxmox, provisioned with Terragrunt + OpenTofu (`bpg/proxmox`) and installed with `nixos-anywhere`. One generic role (`hosts/nixos/proxmox-guest`); hostname, network and SSH keys come from the cloud-init drive, not from the repo. Root login by key only, no Home Manager on the VM, no per-VM roles.

**What lives where.** The repo holds no server value, not even in docs or comments. `just infra-leak-check` catches the Proxmox endpoint host, token id and secret, state passphrase, the S3 endpoint host, the S3 secret key, and every VM name, IPv4, MAC and gateway, in tracked file contents. It does not catch the S3 access key id (it equals the project name), the bucket, node, datastore and bridge names, vmids, sizing, DNS resolvers, tracked path names, commit messages or git history; those stay with the author. Placeholders below: `<endpoint>`, `<bucket>`, `<name>`, `<ipv4>`, `<vmid>`, `<node>`.

- Repo: `infra/` (Terragrunt unit `infra/proxmox/vms`, `infra/root.hcl`, `infra/secretspec.toml` = key *names* only) and `hosts/nixos/proxmox-guest/`.
- OpenBao: the `dotfiles-infra` project, `secret/secretspec/dotfiles-infra/default/<KEY>`. Keys: `TF_VAR_proxmox_endpoint`, `TF_VAR_proxmox_api_token` (full `user@realm!id=secret` form), `TF_VAR_proxmox_insecure`, `TF_VAR_image_datastore`, `TF_VAR_vm_datastore`, `TF_VAR_network_bridge`, `TF_VAR_vms`, `TF_VAR_ssh_authorized_keys` (a reference to `SSH_ID_ED25519_PUB` of the root manifest, one copy), `TF_VAR_tofu_state_passphrase`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (the dedicated S3 state user; the OpenTofu s3 backend reads both from the environment), `TF_STATE_S3_ENDPOINT` (`http://<endpoint>:<port>`), `TF_STATE_S3_BUCKET`.
- State: the S3 bucket `<bucket>` on the RustFS at `<endpoint>`, key `dotfiles-infra/proxmox-vms/terraform.tfstate`. It is encrypted client-side (AES-GCM, key from `TF_VAR_tofu_state_passphrase`, which stays in OpenBao), so the bucket holds only ciphertext. Locking is the s3 backend's native lockfile (`use_lockfile`), verified on this RustFS: a second run while one is active fails with a state-lock error. The unit fails early, naming the variable, when `TF_STATE_S3_ENDPOINT` or `TF_STATE_S3_BUCKET` is empty.

**New Mac.** `just openbao-login`; nothing else is seeded locally. Any Mac that did this and can reach `<endpoint>` can plan, apply, `vm-install` and `vm-deploy` (they read addresses from the state). They fail while the state store is unreachable.

**Provision the state user** (once per RustFS). Limit one S3 user to the prefix. This repo installs neither `mc` nor `aws`; the first run can use `nix run nixpkgs#minio-client` and `nix run nixpkgs#awscli2`. Point `mc` at the RustFS with the `MC_HOST_<alias>` environment variable (`http://<access>:<secret>@<endpoint>:<port>`; URL-encode special characters in the secret), never `mc alias set`, which writes the root credentials to `~/.mc/config.json`. `policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], "Resource": "arn:aws:s3:::<bucket>/dotfiles-infra/*"},
    {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": "arn:aws:s3:::<bucket>", "Condition": {"StringLike": {"s3:prefix": ["dotfiles-infra/*"]}}},
    {"Effect": "Allow", "Action": "s3:GetBucketLocation", "Resource": "arn:aws:s3:::<bucket>"}
  ]
}
```

```bash
mc admin policy create <alias> <policy> policy.json
mc admin user add <alias> <user> <secret>    # the secret is visible in the process list while it runs and lands in shell history unless history is off
mc admin policy attach <alias> <policy> --user <user>
export SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra"
printf '%s' '<user>' | secretspec set AWS_ACCESS_KEY_ID   # likewise AWS_SECRET_ACCESS_KEY, TF_STATE_S3_ENDPOINT, TF_STATE_S3_BUCKET
```

Pipe each value in from stdin, never as an argument.

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
just vm-install <name>   # wait until the VM has booted; Debian cloud image → NixOS via nixos-anywhere
```

`secretspec set` reads the value from stdin when it is piped, so never pass it as an argument (it would land in shell history); pasting multi-line JSON into the interactive prompt is unverified. `SECRETSPEC_REASON` is needed in agent sessions. Names, `vmid`, `mac` and address must be unique across entries; the unit rejects collisions, but only inside `TF_VAR_vms`. `vm-install` refuses unless `debian@<ipv4>` accepts the login, so an installed VM is never reformatted; wait for the VM to boot before running it. It only proves the key is accepted, so the free address and MAC check at the top is yours.

**Change the role.** Edit `hosts/nixos/proxmox-guest/`, then `just vm-deploy <name>` (`nixos-rebuild switch` over SSH as root, built on the VM).

**Remove a VM.** Remove its key with `secretspec get TF_VAR_vms | jq -c 'del(.["<name>"])' | secretspec set TF_VAR_vms` (same exported environment as above), `just infra-plan` (must show exactly that VM's destroy), `just infra-apply`. Removing the last VM on a node also destroys that node's downloaded Debian image. Renaming a key is a destroy plus a create: the name is the `for_each` key and the hostname.

**Rotate the Proxmox API token.** Create the new token in Proxmox, copy the full `user@realm!id=secret` string to the clipboard, then `pbpaste | secretspec set TF_VAR_proxmox_api_token` (same exported environment). Without this the next plan fails with 401.

**Recovery.**

- Unreachable after boot: serial console, `qm terminal <vmid>` on `<node>`. At the GRUB menu (serial too) pick an older generation to roll back, then fix the role and `just vm-deploy <name>`.
- Reinstall: recreate the VM, clear its old host key, wait for Debian to boot, then install again. The recreated Debian has a new host key; without `ssh-keygen -R`, the `vm-install` guard refuses the changed key (its message names this cause, next to "still booting" and "already NixOS").

  ```bash
  just infra-apply "-replace='proxmox_virtual_environment_vm.vm[\"<name>\"]'"
  ssh-keygen -R <ipv4>
  just vm-install <name>
  ```

- Kexec failed while the VM still runs Debian: rerun `just vm-install <name>`.
- State store unreachable: plan, apply and `vm-ip` fail. Nothing is lost; retry when it is back.
- A crashed run can leave the lock object `dotfiles-infra/proxmox-vms/terraform.tfstate.tflock`. Only when no run is active (the id is in the lock error):

  ```bash
  cd infra/proxmox/vms && SECRETSPEC_FILE=../../secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- terragrunt force-unlock <id>
  ```

- State object lost: the VMs still exist. Import them again by VMID, with the same encryption passphrase.
- Encrypted backup: copy the object as is, to a path outside the repo, private (`umask 077`). Never `tofu state pull` into a file: that is decrypted plaintext.

  ```bash
  SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- sh -c 'umask 077; aws --endpoint-url "$TF_STATE_S3_ENDPOINT" s3 cp "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate" "$HOME/infra-state.backup"'
  ```

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
