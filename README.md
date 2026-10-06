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

**What lives where.** The repo holds no server value, not even in docs or comments (`just infra-leak-check` enforces it). Placeholders below: `<name>`, `<ipv4>`, `<vmid>`, `<node>`.

- Repo: `infra/` (Terragrunt unit `infra/proxmox/vms`, `infra/root.hcl`, `infra/secretspec.toml` = key *names* only) and `hosts/nixos/proxmox-guest/`.
- OpenBao: the `dotfiles-infra` project, `secret/secretspec/dotfiles-infra/default/<KEY>`. Keys: `TF_VAR_proxmox_endpoint`, `TF_VAR_proxmox_api_token` (full `user@realm!id=secret` form), `TF_VAR_proxmox_insecure`, `TF_VAR_image_datastore`, `TF_VAR_vm_datastore`, `TF_VAR_network_bridge`, `TF_VAR_vms`, `TF_VAR_ssh_authorized_keys` (a reference to `SSH_ID_ED25519_PUB` of the root manifest, one copy), `TF_VAR_tofu_state_passphrase`.
- State: `$XDG_STATE_HOME/dotfiles-infra/proxmox-vms/terraform.tfstate` (`~/.local/state/dotfiles-infra/proxmox-vms/terraform.tfstate` when unset), on **one Mac only**. It is encrypted (AES-GCM, key from `TF_VAR_tofu_state_passphrase`) and sits outside the repo and every worktree, so removing either does not lose it. The unit creates the directory. Losing the file means importing the VMs again by VMID.

**New Mac.** `just openbao-login`; nothing else is seeded locally. Plan and apply only work on the Mac that holds the state.

**Add a VM.** Set `TF_VAR_vms`, a JSON map keyed by VM name (a DNS label: it becomes the hostname). Keep the existing entries and add the new one:

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
SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec set TF_VAR_vms
just infra-plan          # must show exactly the new entries
just infra-apply
just vm-install <name>   # Debian cloud image → NixOS via nixos-anywhere
```

`secretspec set` prompts for the value when you omit it; do not pass it as an argument (it would land in shell history). `SECRETSPEC_REASON` is needed in agent sessions. Names, `vmid`, `mac` and address must be unique across entries; the unit rejects collisions. `vm-install` refuses unless `debian@<ipv4>` accepts the login, so an installed VM is never reformatted.

**Change the role.** Edit `hosts/nixos/proxmox-guest/`, then `just vm-deploy <name>` (`nixos-rebuild switch` over SSH as root, built on the VM).

**Remove a VM.** Delete its key from `TF_VAR_vms` (same `secretspec set`), `just infra-plan` (must show exactly that VM's destroy), `just infra-apply`.

**Recovery.**

- Unreachable after boot: serial console, `qm terminal <vmid>` on `<node>`. At the GRUB menu (serial too) pick an older generation to roll back, then fix the role and `just vm-deploy <name>`.
- Reinstall: recreate the VM, then install again. The recreate is a plain apply:

  ```bash
  just infra-apply "-replace='proxmox_virtual_environment_vm.vm[\"<name>\"]'"
  just vm-install <name>
  ```

- Kexec failed while the VM still runs Debian: rerun `just vm-install <name>`.

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
