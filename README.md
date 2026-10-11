# ~/.dotfiles

Personal macOS config: **nix-darwin** (system) + **Home Manager** (user), driven by this flake. The same flake also builds the NixOS guests of the [Proxmox VMs](#proxmox-vms) stack.

Hosts `le` and `lex` are entries in the `hosts` table in `flake.nix` (hostname → macOS username). Nothing else names a user or a `/Users/<name>` path: home directories, `system.primaryUser`, Home Manager, Homebrew and nix trusted-users derive from that entry, and `just check` fails on a hardcoded one.

The first part of this README is about the Mac (commands, setup, secrets, shell, apps). The second part, from [Proxmox VMs](#proxmox-vms), is about the NixOS VMs.

## Contents

- [Daily commands](#daily-commands)
- [Layout](#layout)
- [New machine](#new-machine)
- [New host](#new-host)
- [Secrets](#secrets)
  - [The `dotfiles-secrets` wrapper](#the-dotfiles-secrets-wrapper)
  - [Manifest, values and direction](#manifest-values-and-direction)
  - [Activation](#activation)
  - [Status, review and push](#status-review-and-push)
  - [Rules and tools](#rules-and-tools)
  - [SOPS leftovers](#sops-leftovers)
- [Shell](#shell)
- [Homebrew](#homebrew)
  - [Taps](#taps)
  - [Upgrades](#upgrades)
- [Herdr](#herdr)
  - [Install and plugin](#install-and-plugin)
  - [omp agent state](#omp-agent-state)
- [OmniWM](#omniwm)
- [Tern keymap](#tern-keymap)
- [Tern plugin: remote-open](#tern-plugin-remote-open)
  - [Pin and bump](#pin-and-bump)
  - [Image paste is not this plugin's job](#image-paste-is-not-this-plugins-job)
- [Proxmox VMs](#proxmox-vms)
  - [What lives where](#what-lives-where)
  - [Repo, vault and state](#repo-vault-and-state)
  - [secretspec conventions](#secretspec-conventions)
  - [Set up the Mac](#set-up-the-mac)
  - [What the Mac must reach](#what-the-mac-must-reach)
  - [Before every commit that touches `infra/`](#before-every-commit-that-touches-infra)
- [One-time setup](#one-time-setup)
  - [Provision the state user](#provision-the-state-user)
  - [Proxmox side](#proxmox-side)
  - [The Proxmox API token](#the-proxmox-api-token)
  - [Seed a new vault](#seed-a-new-vault)
- [VM operations](#vm-operations)
  - [Add a VM](#add-a-vm)
  - [Resize a VM](#resize-a-vm)
  - [Remove a VM](#remove-a-vm)
  - [Change a role's code](#change-a-roles-code)
  - [Bump the pinned Debian image](#bump-the-pinned-debian-image)
  - [Rotate the Proxmox API token](#rotate-the-proxmox-api-token)
- [Roles](#roles)
  - [Choosing a role: clean or agent](#choosing-a-role-clean-or-agent)
  - [What agent is](#what-agent-is)
  - [Login](#login)
  - [omp](#omp)
  - [mise](#mise)
  - [Tern](#tern)
  - [Podman and zram](#podman-and-zram)
  - [Docker: rootless only, with Compose](#docker-rootless-only-with-compose)
  - [Jumphost: a shell, and its Docker as a context](#jumphost-a-shell-and-its-docker-as-a-context)
  - [just, lazygit and lazydocker](#just-lazygit-and-lazydocker)
  - [bao, secretspec and the tunnel for the vault login](#bao-secretspec-and-the-tunnel-for-the-vault-login)
  - [SSL_CERT_FILE](#ssl_cert_file)
  - [Interactive zsh](#interactive-zsh)
  - [A headless browser for the browser tools](#a-headless-browser-for-the-browser-tools)
  - [Clean to agent](#clean-to-agent)
  - [Agent to clean](#agent-to-clean)
  - [Personal setup: Hindsight, plugins, skills](#personal-setup-hindsight-plugins-skills)
  - [Hindsight](#hindsight)
  - [Mason language servers for omp](#mason-language-servers-for-omp)
- [Identity: fixed at install](#identity-fixed-at-install)
  - [What a change of the entry does](#what-a-change-of-the-entry-does)
  - [Change the address, gateway or resolver](#change-the-address-gateway-or-resolver)
  - [Change the name](#change-the-name)
  - [A VM installed with an earlier version of the role](#a-vm-installed-with-an-earlier-version-of-the-role)
- [Disk encryption and unlock](#disk-encryption-and-unlock)
  - [Passphrases and host keys](#passphrases-and-host-keys)
  - [What the initrd gets](#what-the-initrd-gets)
  - [Unlocking: every boot waits](#unlocking-every-boot-waits)
  - [Console fallback](#console-fallback)
  - [Sizing and growing the disk](#sizing-and-growing-the-disk)
  - [Limits of the encryption](#limits-of-the-encryption)
- [Offline copies](#offline-copies)
  - [What to copy](#what-to-copy)
  - [Make the copies](#make-the-copies)
  - [Check a copy](#check-a-copy)
  - [Restore from a copy](#restore-from-a-copy)
- [Recovery](#recovery)
  - [Unreachable after boot](#unreachable-after-boot)
  - [Stage 2 has no network, or the identity files are wrong](#stage-2-has-no-network-or-the-identity-files-are-wrong)
  - [vm-unlock stops with a host key error](#vm-unlock-stops-with-a-host-key-error)
  - [Reinstall](#reinstall)
  - [Kexec failed while the VM still runs Debian](#kexec-failed-while-the-vm-still-runs-debian)
  - [State store unreachable before a run starts](#state-store-unreachable-before-a-run-starts)
  - [State store dropped during an apply](#state-store-dropped-during-an-apply)
  - [Stale lock](#stale-lock)
  - [Back up the state object](#back-up-the-state-object)
  - [Restore the state object](#restore-the-state-object)
  - [The object no longer decrypts](#the-object-no-longer-decrypts)
- [Notes](#notes)

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

The Proxmox VM recipes (`infra-plan`, `vm-install`, `vm-deploy`, …) are described under [Proxmox VMs](#proxmox-vms).

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

Activation will refuse if OpenBao is unreachable or a declared secret is missing. See [Secrets](#secrets).

Atuin sync logs itself in during that activation (`atuinLogin`); no manual `atuin login`.

## New host

1. Add the Mac to `hosts` in `flake.nix`, keyed by the hostname you want it to have:

   ```nix
   <hostname> = {username = "<id -un on that Mac>";};
   ```

   Add `homeDirectory = "/Users/<folder>";` only if the home folder name differs from the username. Any `profiles`/`system` set there override the defaults.
2. Optional: `cp -r hosts/_template hosts/<hostname>` for host-only settings (display mode, extra packages).
3. First activation as in [New machine](#new-machine) step 4; `just switch` afterwards.

`just home` builds the Home Manager config of the user running it (`id -un`), not of a user named after the host.

## Secrets

The live path is **homelab OpenBao**, not SOPS. `home/secretspec/materialize.sh` keeps the 14 secret files in sync with it.

### The `dotfiles-secrets` wrapper

- The nix wrapper `dotfiles-secrets` (in `home.packages`) pins its `bao`, `jq` and coreutils, so your own `bao` is left alone.
- The `just secretspec-*` recipes run the wrapper of the active Home Manager generation, so they work right after `just home`.
- A bare `dotfiles-secrets` on PATH only follows `just switch`.

### Manifest, values and direction

- **Manifest:** `secretspec.toml` (`[profiles.default]`) lists the names. The table of names, paths and modes is in `materialize.sh`; a test keeps the two lists equal.
- **Values:** `secret/secretspec/dotfiles/default/<NAME>` on `https://openbao.home.0dl.me` (KV v2, field `value`). Every file is byte-exact, trailing newlines included.
- **Direction is proven, not guessed.** Each Mac keeps one record per secret, `~/.local/state/dotfiles/secretspec/<NAME>.base.json`: the vault version and bytes both sides last agreed on. KV v2 version numbers and bytes decide; clocks are display only.

### Activation

`home.activation.secretspecSecrets` runs `dotfiles-secrets apply` on every `just home` / `just switch`.

- It pulls what is safe (no local file, or only the vault changed). It never writes the vault and never prompts.
- Anything that needs a human (local edits, both sides changed, vault rewound or empty, no record, a symlink in the way) prints one banner that points at `just secretspec-sync`, and the switch goes on.
- Vault unreachable (network, timeout, 5xx, 429, sealed): files are kept and the switch goes on for up to 7 days after the last successful contact.
- Rejected credentials (401/403) fail with the fix (`just openbao-login`). A TLS error fails and says to install the CA that signed the certificate.
- A secret missing from both the vault and this Mac always fails.

#### Atuin sync login

`home.activation.atuinLogin` runs `home/secretspec/atuin-login.sh` after materialize and Home Manager's `linkGeneration`. It needs `config.toml`: any earlier, atuin writes its default config and targets Atuin's hosted server.

- `atuin status` OK → nothing (the password is not read).
- Otherwise it runs `atuin login -u loneexile --key ""` with `ATUIN_PASSWORD` from OpenBao (argv only, never on disk). `--key ""` reuses the synced key file without rewriting it, so `ATUIN_KEY` stays in sync.
- Login or network failures print a `!!!!` banner and activation continues.
- `ATUIN_PASSWORD` missing while logged out fails activation.

### Status, review and push

- `just secretspec-status` is read-only.
- `just secretspec-sync` needs a terminal. It shows masked summaries that never print values. `v` opens a read-only `nvim` diff of private copies (when both sides changed, the base is the middle window), and `m` merges. A one-slot backup goes to `~/.local/state/dotfiles/secretspec/backup/<NAME>` before "take vault" and before a merge replaces the file.
- `just secretspec-sync --push NAME` pushes one file without prompts. Use it after you edit a secret file (or run `just secretspec-sync` to review everything). Every push is check-and-set and is read back.

### Rules and tools

- **Never `secretspec delete` these keys.** It destroys every version and the history the engine reasons from. `secretspec set` drops the `writer` field and writes without check-and-set; use `just secretspec-sync --push NAME` instead.
- Login: `just openbao-login` (the recipe name is `openbao-login`, not `secretspec-login`).
- Binary: `~/.cargo/bin/secretspec` (install script, not the nixpkgs package) is still used by `atuin-login.sh` (`ATUIN_PASSWORD`) and by the contract check in `just secretspec-status`. The sync engine does not call it.
- Tests: `just test-secrets`.

### SOPS leftovers

SOPS is leftover, not live: no `secrets/secrets.yaml`, no `sops.secrets.*` in any host/profile. What remains is the `sops-nix` input, `mkDarwin`'s unused darwin module, `.sops.yaml`, and `secrets/note.md`. Ignore those; do not put tokens in `programs.atuin.settings` or git.

## Shell

- zsh + Starship. Completions are cached after `compinit` (do not `source <(tool completion zsh)` on every start).
- **Ctrl-R**: `atuin-fzf-widget` — Atuin's synced DB piped through real [fzf](https://github.com/junegunn/fzf) (`--scheme=history`). Enter fills the prompt; it does not run the command. Atuin is told `--disable-ctrl-r` so it never binds the key.
- **Ctrl-T** / **Alt-C**: fzf file / directory widgets (`programs.fzf.historyWidget.command` is empty on purpose).
- Native Atuin TUI: `atuin search -i`.
- Atuin config: `programs.atuin.settings` in `home/default.nix`. `config.toml` is a read-only store symlink, so `/model`, `atuin setup` and `atuin config set` can't save; change settings in nix.
- The AI token is not in `programs.atuin.settings` (a token there would override it). It comes from secretspec `ATUIN_AI_TOKEN` → `~/.config/atuin/ai-token`, and zsh/bash shells that have a TTY export it as `ATUIN_AI__API_TOKEN`. New shells pick it up; `exec zsh` after it changes.
- To give Ctrl-R back to Atuin: drop `"--disable-ctrl-r"` from `programs.atuin.flags` and delete the `atuin-fzf-widget` `mkOrder 2000` block in `home/default.nix`, then `just home` and `exec zsh`.

## Homebrew

### Taps

- Taps are flake inputs (`flake = false`), registered in `nix-homebrew.taps` (`lib/builders.nix`).
- Adding a third-party formula/cask is that plus `homebrew.brews` / `homebrew.casks`, then `nix flake lock` and `just switch` (not `just home`).
- Tap trust is automatic: `profiles/personal.nix` marks every non-`homebrew/` tap `trusted` in the Brewfile. That is the only trust that survives activation (`brew bundle --force-cleanup` rewrites `~/.homebrew/trust.json` from the Brewfile).

### Upgrades

- `homebrew.onActivation.upgrade = false` so `just switch` stays offline-ish.
- `just update` only moves the lockfile. The taps under `/opt/homebrew/Library/Taps` are synced from it by `just switch`, and upgrading against stale taps fails for formulae with moving download URLs (lightpanda's `nightly` asset).
- `just brew-upgrade` therefore switches first whenever the lock is newer than the active system. `just update-all` is the explicit one-shot.

## Herdr

### Install and plugin

- `herdr` is mise (`herdr = "latest"` in `home/default.nix`), not a nix package.
- **herdr-plus** is a herdr plugin, not a Homebrew tap: the tap only installs a PATH binary and does not register actions.
- `home.activation.herdrPlusPlugin` runs `herdr plugin install cloudmanic/herdr-plus --yes` when `plugins.json` does not already list it.
- Config: `home/herdr/config.toml` (prefix+o projects, prefix+y quick-actions) and `home/herdr/quick-actions/`.

### omp agent state

- herdr has no screen detection for omp. omp's working/idle/blocked state comes only from herdr's omp extension (`~/.omp/agent/extensions/herdr-omp-agent-state.ts`).
- Without it every omp pane reads idle in the sidebar and `resume_agents_on_restore` cannot resume omp.
- `home.activation.herdrOmpIntegration` runs `herdr integration install omp` unless `herdr integration status` already reports it current.
- Running omp sessions only load it after a restart.

## OmniWM

- OmniWM opens its command palette on ⌃⌥Space. macOS ships the same chord as "Select next source in Input menu", so both fire and OmniWM's Health page warns.
- `home.activation.omniwmPaletteChord` turns the macOS shortcut off (symbolic hotkey 61) with `defaults write -dict-add`, which leaves every other system shortcut as it is.
- It then applies the change with `activateSettings -u`, so no logout is needed.

## Tern keymap

Tern runs its tmux preset with prefix ⌃A (`keymap` and `keymap_prefix` in `home/tern/settings.json`), so that its chords match herdr's (`home/herdr/config.toml`). The `keybinds` object holds only what differs from the preset.

- herdr chords with a Tern command: `h` `j` `k` `l` (`focus_pane:*`), `|` (`split_right`), `-` (`split_down`), `1`–`9` (`goto_tab:N`), `shift+x` (`close_tab`), `shift+n` (`new_session`), `shift+w` (`rename_session`), `shift+d` (`close_session`), `shift+s` (`preferences`), `shift+r` (`reload_config`), `e` (`open_scrollback`), `b` (`toggle_sidebar`), `tab` and `shift+tab` (`next_pane`, `previous_pane`), `q` (`quit`: herdr's detach, and Tern's panes live on in its daemon), `?` (`help`).
- Chords that already match in the preset: `c`, `n`, `p`, `,`, `x`, `z`, `s` (the session switcher), `w` (Mission Control, the preset default).
- herdr chords with no Tern command, left as the preset has them: `o` (herdr-plus projects; Tern's `next_pane`), `y`, the annotate chords (`a`, `shift+a`, `m`, `d`, `shift+o`), `shift+g` (new worktree), `shift+p` (rename pane), `r` (resize mode).
- The preset's digits are zero-based (⌃A 1 is the second tab), so the nine `goto_tab:N` entries stay: herdr's `1`–`9` are tabs 1–9. `0` is unbound.
- A normal Preferences save keeps `keybinds`. The Keyboard page's "Restore all defaults" deletes the whole map (Tern 0.7.2). `just home` puts it back: the live file differs from the repo copy, so it is kept as `settings.json.dotfiles-backup` and the repo copy is installed. `just tern-capture` pulls Preferences changes into the repo the other way.
- Tern does not reload `settings.json` when it changes on disk (measured on 0.7.2). After `just home`, run Reload settings in the command palette (or restart Tern). Until then the running Tern holds the old keybinds, and its next Preferences save writes them back over the file.
- Free in both keymaps, if you want Tern's desktop pet on a chord: `"ctrl+a>shift+c": "clawdi"`.

## Tern plugin: remote-open

[remote-open](https://github.com/LoneExile/tern-remote-open) makes links in a pane of a remote host work on the Mac:

- a `file://` link to an html, svg, pdf or image file (copied with `scp`, shown in Tern's browser block);
- an image (`png jpg jpeg gif webp`), as a `file://` link or a plain path: shown in a small viewer whose **Copy image** puts it on the Mac's clipboard and **Save to Downloads** copies it into `~/Downloads` (since 0.2.0);
- a `localhost` link;
- an OAuth sign-in URL whose `redirect_uri` is on localhost (this and the `localhost` link start an `ssh -L` forward; the OAuth one closes itself after ten minutes).

⌥-click leaves a link to Tern. The plugin needs `ssh` to the VM without a prompt and the VM's key in `known_hosts`.

### Pin and bump

The pin lives in `home/default.nix`: `home.file."Library/Application Support/Tern/plugins/remote-open"`, a `pkgs.fetchFromGitHub` store path (Darwin only), not a link to a checkout.

To bump it, set `rev` to the new commit and `hash` to the one that `nix flake prefetch github:LoneExile/tern-remote-open/<rev>` prints, then `just home`.

Do not also run `tern plugin link` on it: two packages with the same id are a duplicate-id error. `tern plugin list` must show `remote-open … ready`.

### Image paste is not this plugin's job

Pasting an image into a remote pane depends on the version of Tern on the VM (`tern remote update`) and on omp's opt-in to paste events (see [Image paste into omp on the VM](#image-paste-into-omp-on-the-vm)), not on this plugin.

## Proxmox VMs

NixOS guests on Proxmox, provisioned with Terragrunt + OpenTofu (`bpg/proxmox`) and installed with `nixos-anywhere`.

- **Roles.** Each VM entry picks a role: `clean` (the default: the generic guest `hosts/nixos/proxmox-guest`, `nixosConfigurations.proxmox-guest`) or `agent` (the same guest plus the `agent-dev` module, `nixosConfigurations.proxmox-agent`). See [Roles](#roles).
- **Identity** is fixed at install. `vm-install` writes the hostname, the static network file and root's SSH keys onto the new system from the VM's entry in the vault. NixOS runs no cloud-init at all: the Proxmox cloud-init drive only serves the Debian bootstrap stage and is ignored afterwards. See [Identity: fixed at install](#identity-fixed-at-install).
- **Disk.** The root disk is LUKS2 and every boot waits for its passphrase. See [Disk encryption and unlock](#disk-encryption-and-unlock).
- **Access.** Root login by key only, and no QEMU guest agent: the VM has no command channel from Proxmox into the guest, and nothing on it reads the cloud-init drive.
- **Users.** The clean role has no other user and no Home Manager. The agent role adds one login user without sudo (see [Roles](#roles)).

### What lives where

The repo holds no server value of this stack, not even in docs or comments. There is one exception, accepted by the author: `home/ssh/jumphost.nix` holds the jumphost's IPv4 address and its SSH host public key, so that the agent VM can pin the jumphost. The Mac's ssh config (`home/default.nix`) reads the same file, so the address is also in the Mac's `~/.ssh/config`.

The rule does not cover the addresses of the Mac's other ssh hosts (`home/default.nix`) or of services in `home/omp/models.yml`, and nothing checks them.

`just infra-leak-check` scans tracked file contents. It catches:

- the Proxmox endpoint host, token id and secret;
- the state passphrase;
- the S3 endpoint host and the S3 secret key;
- every VM LUKS passphrase;
- the Hindsight host and key of every VM;
- every VM name, IPv4, MAC and gateway.

It does not catch these; they stay with the author:

- the S3 access key id (it equals the project name);
- the jumphost's address and host key (above);
- the bucket, node, datastore and bridge names, vmids, sizing and DNS resolvers;
- the initrd host public keys (public by design);
- tracked path names, commit messages and git history.

Placeholders used below: `<endpoint>`, `<bucket>`, `<name>`, `<ipv4>`, `<vmid>`, `<node>`, `<user>` (the agent VM's login user), `<image-datastore>`, `<vm-datastore>`, `<bridge>`, `<role>`, `<tokenid>`, `<project>`.

### Repo, vault and state

- **Repo:** `infra/` (Terragrunt unit `infra/proxmox/vms`, `infra/root.hcl`, `infra/secretspec.toml` = key *names* only), `hosts/nixos/proxmox-guest/` (role clean), `modules/nixos/agent-dev.nix` with `modules/nixos/agent-dev/omp.nix` and `home/linux/` (role agent).
- **OpenBao:** the `dotfiles-infra` project, `secret/secretspec/dotfiles-infra/default/<KEY>`. The keys:
  - `TF_VAR_proxmox_endpoint`, `TF_VAR_proxmox_api_token` (full `user@realm!id=secret` form), `TF_VAR_proxmox_insecure`.
  - `TF_VAR_image_datastore`, `TF_VAR_vm_datastore`, `TF_VAR_network_bridge`.
  - `TF_VAR_vms`.
  - `TF_VAR_ssh_authorized_keys` (a reference to `SSH_ID_ED25519_PUB` of the root manifest, one copy).
  - `TF_VAR_tofu_state_passphrase`.
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (the dedicated S3 state user; the OpenTofu s3 backend reads both from the environment).
  - `TF_STATE_S3_ENDPOINT` (`http://<endpoint>:<port>`), `TF_STATE_S3_BUCKET`.
  - Two JSON maps keyed by VM name that `vm-install` maintains: `VM_LUKS_KEYS` (the disk passphrase of each VM) and `VM_INITRD_HOST_KEYS` (the public key of each VM's initrd SSH host key). Seed both once with `{}` (`printf '{}' | secretspec set VM_LUKS_KEYS`, same for `VM_INITRD_HOST_KEYS`, with `SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra"` exported). Both keys are required, so `infra-plan` and the leak check fail until they exist.
  - A third JSON map is optional and written by hand: `VM_HINDSIGHT` (VM name to the public Hindsight URL and that VM's API key; the manifest default is `{}`). See [Hindsight](#hindsight).
  - Every key of a new vault: [Seed a new vault](#seed-a-new-vault).
- **State:** the S3 bucket `<bucket>` on the RustFS at `<endpoint>`, key `dotfiles-infra/proxmox-vms/terraform.tfstate`.
  - The object is encrypted client-side (AES-GCM, key from `TF_VAR_tofu_state_passphrase`, which stays in OpenBao). Its envelope keeps `lineage`, `serial` and key-derivation metadata in clear, and a lock object is plain JSON that names `user@host` and the path.
  - Terragrunt writes the generated backend file and the `.terraform` cache under `infra/proxmox/vms/.terragrunt-cache/` (gitignored; no state, but they name the endpoint and bucket).
  - Locking is the s3 backend's native lockfile (`use_lockfile`), verified on this RustFS: a second run while one is active fails with a state-lock error.
  - The unit fails early, naming the variable, when `TF_STATE_S3_ENDPOINT` or `TF_STATE_S3_BUCKET` is empty.

### secretspec conventions

These rules hold for every `secretspec` command in the sections below.

- Export `SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra"` first. This is the "same exported environment" that later recipes refer to. `SECRETSPEC_REASON` is needed in agent sessions.
- `secretspec set` reads the value from stdin when it is piped, and drops one trailing newline (measured). Never pass the value as an argument: it would land in shell history. Pasting multi-line JSON into the interactive prompt is unverified.
- `secretspec get` ends its output with a newline, so a `get` piped into a `set` comes back unchanged (measured).
- Never run `secretspec get` with its output on the terminal. Pipe it, or redirect it to a private file: a pipe keeps the old map off the terminal.
- The default provider of `~/.config/secretspec/config.toml` is the `openbao` alias. If yours differs, add `-p openbao`.

### Set up the Mac

First do [New machine](#new-machine): `just openbao-login`, then `just home` (or `just switch`). That brings:

- the tools this stack runs: `terragrunt`, `opentofu`, `bao`, `rsync` and `aws` (`secretspec` is the cargo binary of [New machine](#new-machine) step 2; `jq`, `openssl` and `ssh` come with macOS);
- the SSH key `~/.ssh/id_ed25519`, written from the vault, which logs in to the VMs.

Nothing else is seeded locally. Any Mac that did this and can reach everything below can plan, apply, `vm-install` and `vm-deploy` (they read addresses from the state). They fail while the state store is unreachable.

### What the Mac must reach

LAN, VPN or WARP, whatever your network needs:

- OpenBao, `https://openbao.home.0dl.me`: every recipe.
- The Proxmox API, `<endpoint>` on TCP 8006: plan and apply.
- The state store, `<endpoint>:<port>` of the RustFS: every recipe that reads the state (plan, apply, `vm-install`, `vm-deploy`, `vm-unlock`, `vm-vault-tunnel`).
- The VM: TCP 22 (ssh, `vm-install`, `vm-deploy`, `vm-sync`, `vm-vault-tunnel`), TCP 2222 while it waits in the initrd (`vm-unlock`), UDP 8376 for Tern (role agent).
- The jumphost: TCP 22, through the Mac's ssh entry `jumphost_server` (`vm-jumphost-authorize`).
- The public Hindsight URL: HTTPS (`vm-sync` checks `/health` with the VM's key before it writes anything).

The VM itself needs outbound HTTPS (the Nix binary cache, GitHub, npm, the Hindsight URL) and, for the Docker context and the shell, TCP 22 to the jumphost. Each Proxmox node needs outbound HTTPS to `cloud.debian.org` (see [Proxmox side](#proxmox-side)).

### Before every commit that touches `infra/`

Run `just infra-leak-check`. It expects `no leaks`, reads OpenBao and scans tracked files for the real values. `just test-infra` tests the check itself.

## One-time setup

Do these once per RustFS, Proxmox cluster or vault. Routine work is under [VM operations](#vm-operations).

### Provision the state user

Once per RustFS. This section is the only record of these steps outside IaC.

The user MUST be named `dotfiles-infra` and the policy `dotfiles-infra-state`: the leak check skips the access key id only because it equals the project name. This repo installs `aws` (`awscli2`) but not `mc`, so run the `mc` lines inside `nix shell nixpkgs#minio-client`.

1. Put the root credentials into variables, never typed into a command line (bash or zsh). Never `mc alias set`: it writes the root credentials to `~/.mc/config.json`. Where the root credentials are kept: [The RustFS root credentials](#the-rustfs-root-credentials).

   ```bash
   export MC_CONFIG_DIR=$(mktemp -d)        # without this mc creates ~/.mc
   read -r RUSTFS_ROOT_USER                 # the RustFS root credentials are kept with the stack that deploys the RustFS
   read -rs RUSTFS_ROOT_SECRET              # not echoed, not in history
   export MC_HOST_<alias>="http://$RUSTFS_ROOT_USER:$RUSTFS_ROOT_SECRET@<endpoint>:<port>"   # URL-encode special characters
   unset RUSTFS_ROOT_USER RUSTFS_ROOT_SECRET
   ```

2. Save this policy as `policy.json` outside the repo.
   - `DeleteObject` is needed to release the lock.
   - The prefix condition on `ListBucket` denies the backend's workspace-list call, which it ignores on purpose.
   - `GetBucketLocation` only reveals the region and is what `mc` asks for.

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

#### Rotate the state user's secret

Same order, vault first. Measured: the old secret is refused at once, so runs fail between the two commands; do not rotate during an apply.

```bash
sec=$(openssl rand -hex 24)
printf '%s' "$sec" | secretspec set AWS_SECRET_ACCESS_KEY
mc admin user add <alias> dotfiles-infra "$sec"   # on an existing user this replaces the secret
unset sec
```

#### Remove the state user

Detach, remove the user, remove the policy, then delete the four keys from the `dotfiles-infra` OpenBao project. State objects stay in the bucket until you delete them.

```bash
mc admin policy detach <alias> dotfiles-infra-state --user dotfiles-infra
mc admin user remove <alias> dotfiles-infra
mc admin policy remove <alias> dotfiles-infra-state
```

### Proxmox side

Once per cluster, by hand. The stack changes nothing on the hosts, and it needs no SSH to a node: the provider has no `ssh` block, and the image download and the disk import go through the API. Measured on PVE 9.1.4 with `bpg/proxmox` 0.112.0.

#### Datastores

- `TF_VAR_image_datastore` is a directory datastore with the content type `import` (the Debian image lands there).
- `TF_VAR_vm_datastore` has `images` (an LVM-thin datastore does), for the VMs' disks and their cloud-init drives.
- `pvesm set <datastore> --content <list>` replaces the whole list; it does not add to it. So read the current list first and repeat it with the new type: `grep -A8 '^dir: <image-datastore>' /etc/pve/storage.cfg` on a node, then `pvesm set <image-datastore> --content <current types>,import`.
- `pvesm status --content import` lists the datastores that accept `import`.

#### Node and bridge

- Each `node` in `TF_VAR_vms` is a cluster node name, and `TF_VAR_network_bridge` is a bridge of that name on every such node.
- The VM gets one NIC on it, untagged (the stack sets no VLAN), with the static address of its entry. The bridge must carry that subnet and reach the gateway. Nothing uses DHCP.

#### Quorum

- A VM is created through the cluster. With no quorum Proxmox answers `HTTP 500 ... cluster not ready - no quorum?` and the apply fails.
- It did once, with the second node of a two-node cluster down: the image was downloaded and saved in the state, the VM was not created, and a later apply created only the VM.
- Bring the node back.
- `pvecm expected 1` on the online node tells corosync to expect one vote, which lets a single node go on. It splits the cluster if the other node is only cut off, not down. It was not used here.

#### Outbound HTTPS to Debian

Each node needs outbound HTTPS to `cloud.debian.org`: the node downloads the image itself, the Mac does not. On a node, `curl -fsSI <url from infra/proxmox/vms/main.tf>` must print a 200.

### The Proxmox API token

The stack uses the token to create, change, stop and delete VMs, to download the Debian image into the image datastore and import it as a disk, and to read the cluster.

#### The current token

Measured read-only with the token itself (`GET /access/users/<user>@<realm>/token/<tokenid>` and `GET /access/permissions`), the current token:

- belongs to the built-in `root@pam` user;
- has privilege separation off (`privsep` is 0, so it carries everything its user has);
- never expires;
- holds every privilege (47 on PVE 9.1.4) on `/`.

That is far more than the stack needs. It is also not this stack's own token: it is the token of another stack, copied once into this vault together with the endpoint. Rotating or deleting it means updating both vaults.

#### What the stack needs

This comes from the PVE API reference of the installed 9.1 and the `bpg/proxmox` 0.112.0 docs. It was not tried on a real token: create one, run `just infra-plan` and an apply of a throwaway VM, and add what a 403 names.

| Privileges | Used for | ACL path |
|---|---|---|
| `VM.Allocate`, `VM.Audit`, `VM.PowerMgmt`, `VM.Config.CPU`, `VM.Config.Memory`, `VM.Config.Disk`, `VM.Config.Network`, `VM.Config.HWType`, `VM.Config.Options`, `VM.Config.Cloudinit` | create, read, change, stop and delete a VM | `/vms` |
| `Datastore.Audit`, `Datastore.AllocateSpace` | the VM's disk and cloud-init drive | `/storage/<vm-datastore>` |
| `Datastore.Audit`, `Datastore.AllocateSpace`, `Datastore.AllocateTemplate`, `Datastore.Allocate` | download the image, import it as a disk, delete it with the last VM of a node | `/storage/<image-datastore>` |
| `SDN.Use` | attach the NIC to the bridge | `/sdn/zones/localnetwork`, the zone of local bridges (the path is from Proxmox forum reports; the manual does not name it) |
| `Sys.Audit`, `Sys.AccessNetwork` | read the node; the download (the 9.1 API reference wants `Sys.AccessNetwork` on the node, or `Sys.Audit` and `Sys.Modify` on `/`, which is the pair the bpg docs name) | `/nodes/<node>`, for each node that holds a VM |

#### Create a least-privilege token

To create such a token on a fresh Proxmox, run these as root on a node.

- The commands were checked against the `pveum` man page that the installed Proxmox serves (`/pve-docs/pveum.1.html`, version 9.1.2); none was run.
- The one role at every path is a convenience: a privilege that means nothing at a path does nothing there.
- With `--privsep 1` (the default) the token has its own ACL and never more than its user, so the role goes to both, as the loop does.
- With `--privsep 0` the token carries its user's permissions and the `--tokens` line is not needed (the current token is of that kind).

```bash
pveum user add <user>@pve --comment "dotfiles infra"      # no password: it cannot log in
pveum role add <role> --privs "VM.Allocate, VM.Audit, VM.PowerMgmt, VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.Network, VM.Config.HWType, VM.Config.Options, VM.Config.Cloudinit, Datastore.Audit, Datastore.AllocateSpace, Datastore.AllocateTemplate, Datastore.Allocate, SDN.Use, Sys.Audit, Sys.AccessNetwork"
pveum user token add <user>@pve <tokenid> --privsep 1    # prints the full token id and the secret, once
for p in /vms /storage/<image-datastore> /storage/<vm-datastore> /sdn/zones/localnetwork /nodes/<node>; do
  pveum acl modify "$p" --users <user>@pve --roles <role>
  pveum acl modify "$p" --tokens '<user>@pve!<tokenid>' --roles <role>
done
pveum user token permissions <user>@pve <tokenid>         # what the token can do now
```

The vault string is `<user>@pve!<tokenid>=<secret>`: join the full token id and the secret with `=` (see [Seed a new vault](#seed-a-new-vault)).

### Seed a new vault

Once; skip every key that already exists. The rules for `secretspec` commands are under [secretspec conventions](#secretspec-conventions). The five plain values (endpoint, insecure flag, two datastores, bridge) are not secrets, but they land in shell history.

```bash
export SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra"
printf '%s' 'https://<endpoint>:8006/' | secretspec set TF_VAR_proxmox_endpoint
printf '%s' 'true' | secretspec set TF_VAR_proxmox_insecure    # skips TLS verification of the Proxmox API: true while the Mac does not trust its certificate (Proxmox signs its own by default)
printf '%s' '<image-datastore>' | secretspec set TF_VAR_image_datastore
printf '%s' '<vm-datastore>' | secretspec set TF_VAR_vm_datastore
printf '%s' '<bridge>' | secretspec set TF_VAR_network_bridge
pbpaste | secretspec set TF_VAR_proxmox_api_token                    # the full <user>@<realm>!<tokenid>=<secret> string, from the clipboard
openssl rand -hex 32 | secretspec set TF_VAR_tofu_state_passphrase   # 64 characters, never shown; OpenTofu's pbkdf2 key provider needs at least 16
printf '{}' | secretspec set VM_LUKS_KEYS
printf '{}' | secretspec set VM_INITRD_HOST_KEYS
```

- The passphrase line is for a new vault with no state object only: a new passphrase makes an existing state object and its backups unreadable.
- `TF_VAR_ssh_authorized_keys` needs no command: it reads `SSH_ID_ED25519_PUB` of the root manifest (see [Secrets](#secrets)).
- `VM_HINDSIGHT` is optional (see [Hindsight](#hindsight)).

#### The first VM entry

For the first `TF_VAR_vms`, use this form: the pipe form under [Add a VM](#add-a-vm) starts with `secretspec get`, so it cannot create the key. `vmid` is a number, `role` is left out for `clean`, and `4`, `8192` and `64` are the size the agent VM was proven with:

```bash
jq -n --arg n '<name>' '{($n): {node: "<node>", vmid: 0, mac: "<mac>", ipv4_cidr: "<ipv4>/<prefix>", gateway: "<gateway>", dns: ["<resolver>"], cores: 4, memory_mb: 8192, disk_gb: 64, role: "agent"}}' | secretspec set TF_VAR_vms
```

#### The RustFS root credentials

The four S3 keys come from [Provision the state user](#provision-the-state-user). The RustFS root credentials that step needs are not in this project. They are the keys `TF_VAR_rustfs_root_user` and `TF_VAR_rustfs_root_password` of the secretspec project of the stack that deploys the RustFS, at `secret/secretspec/<project>/default/<KEY>`, field `value` (`<project>` is the `[project] name` of that stack's `secretspec.toml`).

Read them into the variables of step 1 there. `bao kv get -field` puts the value into the variable, not onto the terminal:

```bash
export BAO_ADDR=https://openbao.home.0dl.me
RUSTFS_ROOT_USER=$(bao kv get -mount=secret -field=value secretspec/<project>/default/TF_VAR_rustfs_root_user)
RUSTFS_ROOT_SECRET=$(bao kv get -mount=secret -field=value secretspec/<project>/default/TF_VAR_rustfs_root_password)
```

## VM operations

### Add a VM

1. Check that `<ipv4>` and `<mac>` are not used by another host or guest: ping the address and look through the Proxmox guest configs (`/etc/pve/qemu-server/` and `/etc/pve/lxc/` on every node).
2. Set `TF_VAR_vms`, a JSON map keyed by VM name. Keep the existing entries and add the new one: the pipe form below does that, and on a vault without `TF_VAR_vms` see [The first VM entry](#the-first-vm-entry). The JSON shows the shape.
3. Run the recipes in the second block below.

The fields of an entry:

- **Name:** a DNS label of 4 to 63 characters that is not a word used elsewhere in this repo. It becomes the hostname.
- **Size:** nixos-anywhere's kexec needs at least 1.5 GB of RAM (its `docs/requirements.md`), so use `memory_mb` of at least 2048. The first VM used 4096 MB and 32 GB of disk; the agent role was proven with 4 cores, 8192 MB and 64 GB.
- **`role`** is optional: `clean` when it is left out (see [Roles](#roles)).

```json
{
  "<name>": {
    "node": "<node>", "vmid": 0, "mac": "<mac>",
    "ipv4_cidr": "<ipv4>/<prefix>", "gateway": "<gateway>", "dns": ["<resolver>"],
    "cores": 0, "memory_mb": 0, "disk_gb": 0, "role": "agent"
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

Notes:

- Names, `vmid`, `mac` and address must be unique across entries. The unit rejects collisions, but only inside `TF_VAR_vms`.
- `vm-install` refuses unless `debian@<ipv4>` accepts the login, so an installed VM is never reformatted. Wait for the VM to boot before running it.
- That login only proves the key is accepted, so the free address and MAC check in step 1 is yours.
- Before it formats anything, `vm-install` generates the disk passphrase (first install of that name only) and a fresh initrd SSH host key, and stores both in OpenBao (see [Disk encryption and unlock](#disk-encryption-and-unlock)).
- The `secretspec` rules (stdin, `SECRETSPEC_REASON`) are under [secretspec conventions](#secretspec-conventions).

### Resize a VM

1. Change `cores` or `memory_mb` in its `TF_VAR_vms` entry (the pipe form above).
2. Back up the state object first (see [Back up the state object](#back-up-the-state-object)).
3. Run `just infra-plan` (one in-place update) and `just infra-apply`.
4. Run `just vm-unlock <name>`.

The provider reboots the VM during the apply (measured with `bpg/proxmox` 0.112.0: about 4 s, no pending change left). Running sessions and containers on the VM stop, and the VM then waits in the initrd, hence step 4.

A larger `disk_gb` enlarges the virtual disk only (see [Disk encryption and unlock](#disk-encryption-and-unlock)).

### Remove a VM

1. Remove its key with `secretspec get TF_VAR_vms | jq -c 'del(.["<name>"])' | secretspec set TF_VAR_vms` (same exported environment as in [secretspec conventions](#secretspec-conventions)).
2. `just infra-plan`: it must show exactly that VM's destroy.
3. `just infra-apply`.
4. Delete its entries from the two maps the same way (`secretspec get VM_LUKS_KEYS | jq -c 'del(.["<name>"])' | secretspec set VM_LUKS_KEYS`, and `VM_INITRD_HOST_KEYS`). The passphrase of a destroyed disk is useless.

Removing the last VM on a node also destroys that node's downloaded Debian image. Renaming a key is a destroy plus a create: the name is the `for_each` key and the hostname.

### Change a role's code

Edit `hosts/nixos/proxmox-guest/` (both roles share it), `modules/nixos/agent-dev.nix` or `home/linux/` (agent), then run `just vm-deploy <name>`.

- `vm-deploy` runs `nixos-rebuild switch` over SSH as root, built on the VM. It prints which configuration the VM gets.
- A new kernel or initrd takes effect at the next boot, and every boot waits for `just vm-unlock <name>`.
- `vm-deploy` never rewrites the identity files or the initrd's address: they are written at install.

#### What gets deployed is the working tree, not a commit

- `vm-deploy` runs `nixos-rebuild-ng switch --flake .#<config>` in the checkout that holds the `justfile` (`infra/vm-deploy.sh`).
- `vm-install` passes `--flake <that checkout>#<config>` to `nixos-anywhere` (`infra/vm-install.sh`).
- Both evaluate the git working tree of that directory: tracked files with uncommitted edits are deployed (an edited `home/omp/config.yml` or `models.yml` reaches the VM), and untracked files are not seen (measured with the git fetcher that flakes use).
- So commit or stash before a deploy. Otherwise the VM runs a state that no commit holds, and a rebuild from a clone cannot reproduce it. A clone also has only what was pushed.

### Bump the pinned Debian image

The pin is in `infra/proxmox/vms/main.tf`: `local.debian_image.url`, `local.debian_image.sha512` and the `file_name` of `proxmox_download_file.debian`.

- The file name must equal the last part of the URL (the datastore keeps the volume under that name).
- Pick a dated directory under `https://cloud.debian.org/images/cloud/trixie/` (`<date>-<build>/`, not `latest/`).
- Take the sha512 of the file from the `SHA512SUMS` of that directory (one line, `<sha512>  <file name>`):

```bash
curl -fsSL https://cloud.debian.org/images/cloud/trixie/<date>-<build>/SHA512SUMS | grep ' debian-13-genericcloud-amd64-<date>-<build>.qcow2$'
```

Then run `just infra-plan`. No VM may change, because the VMs ignore `import_from` (`lifecycle.ignore_changes`), so a new image only serves VMs created afterwards. What the plan says about the image resource itself (replace or update in place) was not exercised.

### Rotate the Proxmox API token

1. Create the new token in Proxmox ([Create a least-privilege token](#create-a-least-privilege-token) has the commands).
2. Copy the full `<user>@<realm>!<tokenid>=<secret>` string to the clipboard.
3. Run `pbpaste | secretspec set TF_VAR_proxmox_api_token` (same exported environment as in [secretspec conventions](#secretspec-conventions)).

Without this the next plan fails with 401.

The current token is also the token of another stack: deleting it in Proxmox, or making a new secret for it, breaks that stack too, so update its vault in the same step. A token of its own for this stack ends the sharing.

## Roles

### Choosing a role: clean or agent

The optional `role` field of a `TF_VAR_vms` entry picks the NixOS configuration. Leaving it out means `clean`.

- `variables.tf` refuses any other value at plan time.
- `vm-install` and `vm-deploy` build `.#proxmox-guest` for `clean` and `.#proxmox-agent` for `agent` (`infra/vm-config.sh`). `just test-roles` evaluates both and fails when the clean guest gains a user, a port or an agent package.
- A role changes no Proxmox resource. `just infra-plan` shows a flip only as a change to the `vms` output (`role = "clean" -> "agent"`), and the deploy reads the role from the vault, not from the state, so no `infra-apply` has to come first.
- A deploy prints which configuration the VM gets. Re-seeding `TF_VAR_vms` from an older value without the role silently means `clean`, which removes the agent user at the next deploy.
- A different `cores`, `memory_mb` or `disk_gb` is an in-place update of the Proxmox VM (measured: `1 to change`), and the LUKS root does not follow a bigger disk (see [Disk encryption and unlock](#disk-encryption-and-unlock)). So a resize with a new role is a reinstall: the recipe under [Reinstall](#reinstall) (`-replace`, `vm-install`, `vm-unlock`).

#### Set the role

Save a copy of the map to a private file first, and check that the name exists (a mistyped name would add a stub entry). Then run this (same exported environment as in [secretspec conventions](#secretspec-conventions)):

`umask 077; secretspec get TF_VAR_vms > <private file> && jq -e --arg n "<name>" 'has($n)' <private file> >/dev/null && jq -c --arg n "<name>" '.[$n].role = "agent"' <private file> | secretspec set TF_VAR_vms`

### What agent is

`nixosModules.agent-dev` has these options:

- `dotfiles.agent.enable`;
- `.omp`, `.mise`, `.tern`, `.gh`, `.mason`, `.podman`, `.docker`, `.jumphost`, `.tools`, `.vault`, `.caBundle`, `.zsh` and `.browser`, each with `.enable`, each on when the agent is;
- `.sync.hindsight`, `.sync.plugins` and `.sync.skills` (see [Personal setup](#personal-setup-hindsight-plugins-skills)), each on when the agent is;
- `dotfiles.agent.user`, default `lex`.

What the agent role gives the VM:

- A login user outside `wheel` with no sudo (root still logs in by key), zsh, and `linger` so that its user services start at boot.
- Home Manager (`home/linux/agent.nix`, not the Mac's `home/default.nix`): zsh, starship, git with the Mac's identity, direnv with nix-direnv, mise.
- `programs.nix-ld`, so that glibc programs that were not built for NixOS run (mise's runtimes, omp, Tern).
- omp, `gh`, rootless podman and rootless Docker, `just`, `lazygit`, `lazydocker`, `bao`, `secretspec`, a headless Chromium behind `/opt/google/chrome/chrome` for the browser tools, zram swap, `curl`, `gcc` and `gnumake`.
- zsh with the Mac's aliases, options, keybindings and plugins.

The Home Manager input is `home-manager-nixos` (release-25.11, following `nixpkgs-nixos`). The `home-manager` input is master and does not evaluate against nixos-25.11 (it needs nixpkgs-unstable's `lib/services/lib.nix`).

`proxmox-guest` is untouched: its toplevel derivation is byte-identical with and without this module in the flake.

### Login

- The user logs in with the same keys as root.
- An activation script copies `/root/.ssh/authorized_keys`, which `vm-install` wrote, to the root-owned `/etc/ssh/agent-authorized-keys` at every activation. sshd reads that file for every account (`services.openssh.authorizedKeysFiles`).
- Root's list stays the one list (a key removed there is gone for the user at the next deploy or reboot). Root writes nothing inside the user's home, and no key is in the repo or the Nix store.
- The user's own `~/.ssh/authorized_keys` stays the user's. `tern remote setup` creates it and adds the Mac's Tern device key (which lets that key log in over SSH as the user too), and keys the user adds there stay across deploys and reboots.

### omp

`omp update` works on the VM, as on the Mac.

#### A pinned seed, and a copy that is yours

- The pin is `modules/nixos/agent-dev/omp.nix` (the GitHub release asset of `can1357/oh-my-pi`, version `18.8.7`). It is a Bun-compiled binary, so nothing may strip or patch it; it runs through nix-ld.
- The pinned package stays on the system PATH as the fallback. Home Manager copies the same binary once to `~/.local/bin/omp` (`home/linux/seed-user-binary.sh`, a step after `writeBoundary`): a regular file of the user's, mode 755, which comes before the Nix profile directories on every zsh's `PATH`.
- `omp update` refuses to run from the Nix store (it replaces its own file, and the store is read-only), but it replaces this copy. It downloads the release asset, checks its size and sha256, writes a new file beside the old one and swaps it in with renames. Measured on the VM, 18.8.7 to 18.8.9: the new file's sha256 was the release's, and no `.bak` or `.new` file stayed.
- So you update omp on the VM, with `omp update` (`omp update --check` only looks).
- A shell that already ran `omp` before this was deployed has the store path in its command hash: `hash -r`, or open a new shell.

#### A deploy never touches the copy once it is there

- The copy is made only when `~/.local/bin/omp` is missing or a symlink. A symlink is replaced by a copy, and the step says what it pointed to; a symlink to a directory is left alone.
- A regular file is never replaced, so neither `just vm-deploy` nor a reboot (Home Manager activates at every boot) downgrades an omp that you updated. Measured: a deploy after an `omp update` to 18.8.9, with the pin at 18.8.7, left the file's inode, mtime and sha256 as they were.
- A newer pin in the repo does not reach a VM that has its own copy. The pin only decides what a new install, or a VM whose copy was deleted, starts with.
- The copy is written to a temporary file in `~/.local/bin` and renamed over the target, so nothing reads half a program.

#### Go back to the pinned version

On the VM: `rm ~/.local/bin/omp`, then `just vm-deploy <name>` on the Mac (or reboot the VM: the next activation makes the copy). Until then `omp` is the store fallback.

#### Bump the pin

This only changes the seed. Change `version` and `hash` together, then `just vm-deploy <name>`.

- `nix store prefetch-file --json <release asset URL>` prints the hash.
- Compare it with the digest the release page lists for the asset: `gh release view v<version> --repo can1357/oh-my-pi --json assets`.

#### Config

- omp's config (`home/omp/config.yml`, `models.yml`, `mcp.json`, as they are in the working tree when you deploy: see [What gets deployed is the working tree, not a commit](#what-gets-deployed-is-the-working-tree-not-a-commit)) is copied into `~/.omp/agent/` as writable files. So is mise's global config (`~/.config/mise/config.toml`). `home/linux/writable-copy.sh` does the copying.
- The repo copy replaces the file only when the repo copy is new since the last install (a hash under `~/.local/state/dotfiles/writable-copy/`). An edit made on the VM is then kept as `<name>.dotfiles-backup` (one previous version). Otherwise an edit stays across deploys and reboots (Home Manager activates at every boot).
- Nix pushes no secret. Put `~/.omp/.env` in place by hand: it is deliberately not synced (the command is under [The omp .env file](#the-omp-env-file)). The one secret that reaches the VM is the Hindsight key that `just vm-sync` writes (see [Hindsight](#hindsight)).
- The `gh` login is yours as well: `gh auth login` on the VM.
- The omp config in the repo was written for the Mac, and these parts cannot work on the VM: the omniroute, anthropic-refresher and xai-refresher providers (homelab addresses, unreachable from the VM), the `unitllm` provider, and the MCP servers `zennotes`, `open-design` and `unsplash` (Mac paths). `codegraph` is not installed either.
- The hindsight memory backend works through the public URL and key that `vm-sync` sets as environment variables (see [Hindsight](#hindsight)).
- Models and roles that name a provider without a credential on the VM fail until you change them.

### mise

- The global tools are node, python 3, uv, go, rust, bun and `npm:pnpm`, all `latest` (`3` for python). They are installed on first use (`not_found_auto_install`) or by `mise install`, into `~/.local/share/mise` (outside Nix).
- The agent role uses nixpkgs-unstable's mise. nixos-25.11's (2025.11.7) takes the free-threaded CPython build for python 3.13 and later and fails with "Python installation is missing a `lib` directory"; 2026.8.6 installs python 3.14.
- `node.compile` is off because mise compiled node from source by default on this VM and failed on a missing python. The prebuilt node runs through nix-ld (measured: `mise use -g node@lts`, then `node --version`).
- `mise use -g` works because the global config is a writable file.
- mise's tools float (`latest`, installed on first use), unlike the omp seed, which is pinned by hash (the omp you run is the copy that `omp update` keeps current: see [omp](#omp)). `mise use -g <tool>@<version>` pins one.

### Tern

- `tern remote setup <user>@<ipv4>`, run on the Mac after the role is deployed, downloads Tern (the VM does it itself) into `~/.local/share/tern`, links `~/.local/bin/tern`, writes the user service `~/.config/systemd/user/tern-remote.service` and starts it.
- `tern remote doctor <user>@<ipv4>` checks it, and the Mac's host list (`~/Library/Application Support/Tern/hosts`) gains `<user>@<ipv4>`.
- Tern's binary, its state in `~/.config/tern` and that unit are Tern's, not managed by `vm-deploy`. `tern remote update <user>@<ipv4>` updates the binary.
- The service serves QUIC on **UDP 8376** (measured with `ss`; the Tern service on the Mac listens on 8377 because it is told to). The firewall opens exactly that, only with `dotfiles.agent.tern.enable`.

#### Direct LAN only: the drop-in

- A drop-in that the module installs (`tern-remote.service.d/10-direct-lan.conf`) starts the service with `--relay none --pkarr none --no-iroh`. It never contacts iroh.stencil.so or a relay, and only a Mac with a UDP path to the VM reaches it (measured: the service opens no other UDP port).
- Deploy before `tern remote setup`. A service that started without the drop-in connected to the iroh relay and published an endpoint id, and its first setup added the host to the Mac's list by endpoint id (`<user>@<endpoint id>`). After the drop-in and a restart, `tern remote setup` again adds `<user>@<ipv4>`; the endpoint-id line is then stale and can go from the hosts file.
- Without a UDP path from the Mac to the VM (another network, no VPN) the Mac cannot reach it. Before the drop-in, setup fell back to iroh; with it, nothing does. Turning relay or iroh back on is a deliberate change that this module does not make.

#### Limits to know

- The drop-in repeats Tern 0.6.0's own `ExecStart` (`~/.local/share/tern/build/tern remote serve --user --state-dir ~/.config/tern`) with the three flags added. If a `tern remote update` changes that command, change the drop-in too.
- A running service takes a changed drop-in only after `systemctl --user restart tern-remote.service` or a reboot. Check with `ps -u <user> -o args=` that its line holds `--no-iroh`.

#### Image paste into omp on the VM

This is an opt-in, in `~/.zshenv`.

- Tern hands a program a pasted image, or the bytes of a copied file, only if the program turns on paste events first (it writes `ESC [ ? 5522 h`).
- omp 18.8.7, 18.8.8 and 18.8.9 never write it (measured with a pty logger under Tern: no 5522 byte in any of the three, each started in a Tern pane).
- So ⌘V in an omp pane on the VM types the Mac path of a copied file (omp answers `Image not found at <that path>`) or pastes nothing for an image-only clipboard (`Clipboard is empty`).
- In v18.8.9 omp registers the opt-in as a start listener (`input-controller.ts:894-895`). Reading the source, it is probably added after the UI started, so it never runs (not tested). No setting or environment variable of omp turns it on.

The fix:

- `home/linux/omp-image-paste.zsh` is an `omp` function that goes into `~/.zshenv` with the Tern piece (`dotfiles.agent.tern.enable`).
- It writes the sequence before omp and resets it after, however omp ends (exit, error exit, Ctrl-C), only when stdin and stdout are terminals and `TERM_PROGRAM` is `tern`.
- Arguments and exit status pass through, so `omp update`, `omp --version` and `omp -p ... | less` are unchanged.
- It needs Tern 0.7.x on the VM (a 0.6.0 service lists only `text/plain`).
- A pane that was running before the deploy needs a new shell (`exec zsh`) and then omp started again: an omp that already runs never gets it.

Where it runs:

- Tern runs a pane's program through the login shell (Tern's own docs for `agent_command`). Measured on the VM and on the Mac, the pane's process is `zsh -l` (an interactive login shell, no `-c`) with omp as its child, so a typed `omp` calls the function.
- It is in `~/.zshenv` rather than `~/.zshrc` so that a `zsh -c omp` gets it too (the test runs both forms).
- The process line of an agent block (Tern's chat surface for `omp`) was not observed. The function is for the terminal pane, where ⌘V goes through the terminal.

Measured on a throwaway Tern 0.7.1 daemon on the VM, in an isolated Tern window, never the real session:

- A PNG-only clipboard gives an image chip.
- A clipboard with a file URL next to the PNG is listed as `text/plain`, `image/png` and `text/uri-list`, and omp takes the PNG and shows a chip. The layout is the one that Vorssaint's copied screenshots should have, taken from its code; the clipboard was not made by Vorssaint itself.
- Without the opt-in the same clipboard gives `Image not found at <that path>`.
- A text paste is unchanged.

Tests: `home/linux/omp-image-paste_test.sh` (in `just test-infra`) tests the function in a real pty. `infra/roles-check.sh` checks that it is in `~/.zshenv` byte for byte with the Tern piece and gone without it.

### Podman and zram

`virtualisation.podman` is rootless: the user has subuid and subgid ranges, and the `newuidmap` wrappers come with NixOS. `podman run --rm docker.io/library/hello-world` works as the user. `zramSwap` is on.

### Docker: rootless only, with Compose

Option `dotfiles.agent.docker.enable`, on when the agent is.

- It sets `virtualisation.docker.rootless` (without `setSocketVariable`, see below) and the package `docker_29` (29.6.0).
- nixos-25.11's default `pkgs.docker` (28.5.2) is marked insecure, unmaintained since November 2025, and refuses to evaluate. `docker_29` is the same nixpkgs, so no unstable.
- `docker compose` (2.40.3) and `docker buildx` (0.29.1) come with that package (measured: `docker compose version`).

#### Why rootless

The rootful daemon (`virtualisation.docker.enable`) listens on `/var/run/docker.sock` for the `docker` group. That group is root on the machine (`docker run -v /:/host`), which the user (no sudo, not in `wheel`) must not be.

So there is no rootful daemon, no `docker` group, nobody in it and no `/var/run/docker.sock`. `just test-roles` fails if one appears, and also if podman's `dockerCompat` or `dockerSocket` is turned on (that would make the `docker` command podman).

#### The daemon

- The daemon is the NixOS user unit `docker.service` (`dockerd-rootless`, refused for root) of the user: socket `/run/user/<uid>/docker.sock`, data in `~/.local/share/docker`. It starts at boot through linger.
- A NixOS switch only loads a user unit that it adds and never starts it (measured on the first deploy: the unit was there and inactive), and Home Manager starts only its own units. So a Home Manager activation step (`home/linux/start-user-unit.sh`, after `reloadSystemd`) starts `docker.service`. At boot Home Manager runs before the user manager exists, the step does nothing, and the manager starts the unit itself.
- Rootless podman stays beside it and keeps working (`podman run --rm docker.io/library/hello-world`, measured with Docker running). Their storage is separate (`~/.local/share/containers` against `~/.local/share/docker`). Both map the user's one subuid and subgid range (`lex:100000:65536`, one line in `/etc/subuid` and `/etc/subgid`) into a user namespace of their own, so nothing is shared.

#### How lazydocker and the docker CLI find the daemon

They use a Docker context, not `DOCKER_HOST`.

- Home Manager makes the context `rootless` (`unix:///run/user/<uid>/docker.sock`) and makes it current, once, when it creates it (`home/linux/docker-contexts.sh`, a step after `writeBoundary`). A context that you switched to later stays current, and a context that exists with another host is updated.
- `DOCKER_HOST` is **not** exported on purpose. Measured, while it is set: `docker context use` only warns that the variable overrides the active context, `DOCKER_CONTEXT` is ignored, and so is lazydocker's context lookup (`docker --context` alone still wins). So `setSocketVariable` (which exports it to every shell) would make the `jumphost` context unusable.
- The current context is read from `~/.docker`, so `docker`, `docker compose` and lazydocker find the rootless daemon in an ssh login shell, in `zsh -c`, in `zsh -ic` with and without a terminal, and in a shell started by a user service (Tern's way). `docker ps` works in each.
- lazydocker has no non-interactive mode. Run in a real terminal with a container up, it lists the container, and with `DOCKER_HOST` pointing nowhere it says it cannot connect.
- `DOCKER_HOST=…` or `DOCKER_CONTEXT=jumphost` sets another daemon for one command.

#### Ports that containers publish are not reachable from the LAN

- rootlesskit binds `-p 18080:8080` on all interfaces of the VM, and the firewall is unchanged (TCP 22 and UDP 8376 only). So only the VM itself (`127.0.0.1`) gets through. Measured from the Mac: the port is closed, port 22 open.
- Reach one with `ssh -L`.
- Opening a port to the LAN is a change of `networking.firewall` in the module on purpose, never a side effect of `docker run`.
- Rootless Docker cannot bind ports below 1024 either (the sysctl is not changed).

#### Flip to clean: stopping the daemon

- `vm-deploy` stops `docker.service` before the switch (the same place where the plugin and Mason installs are stopped), so no daemon and no container runs on as the removed user. Measured: the stop takes about 11 s, leaves no process of the user, and removes the socket.
- It then asks systemd whether the unit is still up and refuses the flip (exit 1, before the role changes) if it is.
- This is the same step as the removal of synced files, so it needs the VM's host key to be pinned on this Mac. When it is not, `vm-deploy` says that the removal is skipped, and the daemon and its containers keep running as the removed user until the next boot.
- If the switch itself fails after the stop, the role is still `agent` but Docker stays down until `systemctl --user start docker` or the next deploy.
- Images, containers and volumes stay in `~/.local/share/docker` with the rest of the home, like podman's.

#### Turning Docker off

`dotfiles.agent.docker.enable = false` removes the daemon unit, the `docker` CLI, the start step and the context step (the contexts already made stay in `~/.docker`).

- The jumphost piece needs Docker, so turn that off too (an assertion says so otherwise).
- Measured: the switch does **not** stop a daemon that is running (its unit file is gone, and the daemon and its containers keep running). So stop it first (`systemctl --user stop docker`), or after the switch by the same name. `~/.local/share/docker` stays.
- The tools and podman stay.

#### Docker updates

A deploy never restarts a daemon that is running (`start` on an active unit does nothing, and NixOS does not restart user units). After a change of the Docker or rootlesskit package the old daemon keeps running until `systemctl --user restart docker` (which stops the containers) or the next boot, while the `docker` CLI is already the new one.

### Jumphost: a shell, and its Docker as a context

Option `dotfiles.agent.jumphost.enable`, on when the agent is. It needs `docker.enable` (an assertion says so).

It gives the user two things on the jumphost, each through its own key:

- a login shell: `ssh jumphost_server`, the same name as on the Mac;
- a second Docker context, `jumphost` = `ssh://jumphost_docker`. So `docker --context jumphost ps`, `docker context use jumphost` and lazydocker reach the Docker daemon of the jumphost. The local rootless daemon stays the default.

#### Host values and the VM's ssh entries

- The host values (its name, address, user and ed25519 host key) are in `home/ssh/jumphost.nix`. It is one file that the Mac's ssh config (`home/default.nix`) and the VM's both read, so they cannot drift (the Mac's darwin derivation is unchanged by that refactor).
- On the VM there are two ssh entries for that one host, and no other entry:
  - `jumphost_server` (the Mac's name for it) with the shell key `~/.ssh/id_ed25519_jumphost_shell`;
  - `jumphost_docker` with the Docker key `~/.ssh/id_ed25519_jumphost`, used by the context.
- Each entry has only its own key (`IdentitiesOnly`), `StrictHostKeyChecking yes` against one pinned file (`~/.ssh/known_hosts.d/jumphost_server`, the jumphost's public host key) and no global known_hosts.
- Two keys, not one: sshd picks the `authorized_keys` line by the key, so one key cannot be both the restricted Docker line and a login.
- None of the Mac's `Host *` defaults (`User root`, `StrictHostKeyChecking no`, `UseKeychain`) and none of the Mac's other keys or hosts are there.

#### The keys

- Both keys are made on the VM, once, by a Home Manager step before the links (`home/linux/ssh-key.sh`): ed25519, no passphrase, mode 600, with the comments `user@host docker-jumphost` and `user@host shell-jumphost` built at run time.
- Their private halves never leave the VM and are never printed, copied, or stored in the vault or the repo. An existing key is never replaced.

#### Authorizing the keys

One step on the Mac per key: `just vm-jumphost-authorize <vm>` for the Docker key, `just vm-jumphost-authorize <vm> shell` for the shell key (`infra/vm-jumphost-authorize.sh`). A VM gets a shell only when you run the second.

- It reads only the public half over ssh (a regular file, at most 2 KiB; the VM's host key must be pinned, like `vm-sync`).
- It appends it to the jumphost's `~/.ssh/authorized_keys`:
  - the Docker key as `restrict,command="docker system dial-stdio" ssh-ed25519 <key> <vm> docker-jumphost`;
  - the shell key as `ssh-ed25519 <key> <vm> shell-jumphost`, with no options, like the Mac's own key.
- The script on the jumphost writes those two forms and nothing else: any other line, a line with a line break, or a comment that does not end in the right purpose is refused.
- It makes a backup first (`authorized_keys.bak-<timestamp>`), writes atomically, and works once: a second run changes nothing and makes no second backup. It touches no other line.
- It refuses a VM name with odd characters, a kind other than `docker` or `shell`, a key that is not ed25519, a link in place of `authorized_keys`, and a key that is already there with other options (so a shell key that is already a restricted line stays restricted). A different comment does not count: such a line is already authorized and is left as it is.

The Docker key can only run the Docker API stream: no shell, no pty, no port forwarding, no sudo (`restrict`). The shell key has all of that, as the jumphost's account. The jumphost's `docker` group is root-equivalent there, so either key gives the user that much power on the jumphost; the shell key also gives forwarding through it.

#### Revoking a key

- The shell: delete every line of the jumphost's `authorized_keys` that carries the comment `<vm> shell-jumphost`. The context keeps working.
- Docker: delete every line that carries `<vm> docker-jumphost`.
- The Mac builds those comments from the VM's name and never takes the comment that the VM wrote, so a VM cannot choose the text that names its line.
- There can be more than one line per comment. A reinstalled VM makes new keys, and the script appends them next to the old ones and never removes a line, so every old key stays valid until its line is gone. Tell them apart by fingerprint, with the steps under [Reinstall](#reinstall).
- The key files on the VM can go too.

#### lazydocker and the jumphost context

lazydocker 0.24 reaches an `ssh://` context with `ssh -L` socket forwarding, which `restrict` forbids. So in the agent role `lazydocker` is a small wrapper (`home/linux/lazydocker-ssh.sh`):

- for an `ssh://` context it starts a local bridge (`socat` listening on a mode-600 socket in `$XDG_RUNTIME_DIR`, each connection running `ssh jumphost_docker docker system dial-stdio`), points lazydocker at it with `DOCKER_HOST`, and removes the bridge when lazydocker exits;
- for any other context, or when `DOCKER_HOST` is already set, it runs lazydocker unchanged.

#### Turning the jumphost piece off

- `dotfiles.agent.jumphost.enable = false` removes both ssh entries, the pinned file, the key step, the context step and the wrapper.
- The key files and the contexts already made stay in the home (like the rest of `/home/lex`), and the authorized lines stay on the jumphost until you remove them.
- The agent-to-clean flip leaves the keys and the contexts in the home and never touches the jumphost.

### just, lazygit and lazydocker

Option `dotfiles.agent.tools.enable`, on when the agent is.

- They are packages of the user (`/etc/profiles/per-user/lex/bin`, so on the `PATH` of every login, Tern and `zsh -c` shell), from nixos-25.11: `just` 1.43.1, `lazygit` 0.56.0, `lazydocker` 0.24.2. Unstable has 1.58.0, 0.65.1 and 0.25.2; nothing in 25.11 is broken, so it is not used.
- Their config (`~/.config/lazygit`, `~/.config/lazydocker`) is theirs: nothing manages it, and the first run of lazydocker writes its own.
- The Mac's alias `ld` (lazydocker) and function `lg` (lazygit that follows the directory change on exit) find their tools on the VM.
- Off: the packages go, nothing else.

### bao, secretspec and the tunnel for the vault login

Option `dotfiles.agent.vault.enable`, on when the agent is. It installs packages of the user for the UnitLLM repo on the VM (its `just vault-login`, `just vault-status` and `secretspec` runs):

- `bao`: `openbao` 2.5.5 of nixos-25.11; its `bin` holds `bao` and no `vault` alias.
- `secretspec`: 0.21.1 of nixpkgs-unstable, because nixos-25.11's 0.3.3 is too old. Measured on the VM with no token, `secretspec check -n -p unitllm` and `-p unitllm-agent` stop with "No Vault token found" and "No JWT available", not with a parse error.

Nothing else comes with it: no token, no config, no login, and no OpenTofu, kubectl, terragrunt, talosctl or helm (Terraform stays on the Mac).

#### The tunnel

The vault's OIDC role allows one redirect, `http://localhost:8250/oidc/callback`, and `bao login` listens on the machine it runs on. So on this headless VM the sign-in finishes in the Mac's browser through a tunnel.

`infra/vm-vault-tunnel.sh` runs `ssh -N -L 8250:localhost:8250 <user>@<ipv4>` in the foreground, with the host key pinned and on loopback only. It refuses when TCP 8250 is in use on the Mac or the VM has the clean role.

```bash
just vm-vault-tunnel <name>   # on the Mac, kept open; Ctrl-C ends it
just vault-login              # on the VM, in the UnitLLM repo; open the URL it prints in the Mac's browser
```

Measured without signing in:

- `bao login -method=oidc` on the VM prints the sign-in URL on stderr, with that callback as its `redirect_uri`, says that it cannot open a browser (no `xdg-open`) and keeps waiting.
- Through the tunnel the Mac reaches its listener: `GET /` is a 404, and `GET /oidc/callback` with no parameters gets bao's page, after which bao exits with "Expired or missing OAuth state".

#### The token

The token that the UnitLLM recipe saves (`~/.config/openbao/unitllm-gateway.token`) has that vault's `admin` policy for 24 h, and anything running as lex on the VM can read it.

Revoke it with `bao token revoke -self` (the address and the token as the UnitLLM justfile exports them) and delete that file when you are done.

### SSL_CERT_FILE

Option `dotfiles.agent.caBundle.enable`, on when the agent is. It sets `SSL_CERT_FILE` for the user.

- mise's prebuilt Python finds no CA bundle on NixOS (`/etc/ssl/certs` holds only the bundle links) and failed every HTTPS request with `CERTIFICATE_VERIFY_FAILED`.
- So `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt` is exported by `~/.zshenv` (every zsh: an ssh login, `zsh -c`, `zsh -lc`, the shell of a Tern session, omp's shell; a value that is already set is kept) and set in the user manager's environment (user services).
- That turned a Python HTTPS GET from failing in 7 of 7 kinds of shell and service into HTTP 200 in all 7 (measured), an omp that started before the deploy included.

### Interactive zsh

Option `dotfiles.agent.zsh.enable`, on when the agent is (`home/linux/zsh.nix`). It gives the VM the Mac's aliases, options, keybindings and plugins.

#### Shared with the Mac: one source of truth

- `home/zsh/config/aliases.zsh`, `options.zsh` and `keybindings.zsh` are sourced from the store copy that the flake names, byte for byte (`just test-roles` compares each with the repo file, and the Mac's derivation does not change). So editing one changes both machines.
- The plugins come from nixpkgs (nothing is fetched at shell start): `zsh-syntax-highlighting` 0.8.0, `zsh-autosuggestions` 0.7.1, `zsh-completions` 0.35.0, `zsh-history-substring-search` 1.1.0, `fzf-tab` 1.2.0, and `fzf` 0.67.0 as a user package, which fzf-tab calls (the package only: not the Mac's `programs.fzf` Ctrl-T, Alt-C and `**` bindings).
- `fzf-tab-source` (Freed-Wu) is in no nixpkgs (25.11 and unstable: measured), so it is pinned in `home/linux/zsh.nix` by commit (`3253ab5`, 2026-07-21) and hash. Bump it with `nix flake prefetch github:Freed-Wu/fzf-tab-source`.
- The load order is the Mac's `home/zsh/zshrc`: the three files, then the plugins, then `compinit`.

#### Only a real terminal gets any of it

- A shell without a terminal (omp's shell, a scripted `zsh -i`) leaves `~/.zshrc` at once, as the Mac's early exit does (order 500), keeping only `mise activate`.
- `zsh -c` and `zsh -lc` never read `~/.zshrc`.
- So they load no plugin and print nothing. `HINDSIGHT_API_URL`, `HINDSIGHT_API_TOKEN` and the mise and Tern `PATH` (all from `~/.zshenv` and the profile) stay set (measured). Also measured: omp's shell tool ran commands through its shell without an error.

#### What differs from the Mac

- The Mac's `options.zsh` also installs a `chpwd` hook that sources a `.env` file of the directory you `cd` into (interactive terminal only). It is loaded here too, so a Docker Compose `.env` that is not shell syntax (spaces, `$`) is sourced as shell code at `cd`.
- `EDITOR` and `VISUAL` are `vim` when there is no `nvim` (`options.zsh` sets them to the output of `which nvim`, which is the text `nvim not found` here).
- `options.zsh`'s `HISTFILE=~/.zhistory` replaces Home Manager's `~/.zsh_history` as on the Mac, and the old file is not read any more.
- The aliases of tools the VM does not have (`brew`, `zap`, `open`, `kubectl`, `gdu-go`, `sdl-freerdp`, ...) stay defined. Loading the files runs none of them (`lg`, `dk` and `pkgup` only define functions; the test shims every command that an alias names and asserts that none was called), and calling one says `command not found`.

#### The completion trap

Measured.

- NixOS's `/etc/zshrc` ran `compinit` before `~/.zshrc`, so a completer that `~/.zshrc` adds to the `fpath` afterwards (zsh-completions) was never registered in `$_comps`. Replayed on the VM, `_afew` is `none` in that order and `_afew` in the role's.
- So with this option `programs.zsh.enableGlobalCompInit` is off (`enableCompletion` stays on: it links the system profile's completers) and `~/.zshrc` makes the one `compinit` call, after the plugins.
- It is cached like the Mac's: `-C` (no security audit) while the dump is under a day old, a full run once a day, and a full run for every new system generation too. A deploy changes the packages that carry completers, and a dump from before would hide them; a young dump of the older `/etc/zshrc` call did exactly that.
- The dump is `~/.cache/zsh/zcompdump` with `zcompdump.key`.
- Measured on the VM: 87 ms for `zsh -i -c exit` in a terminal with a warm dump (22 ms with no rc file at all, 477 ms with a cold dump), one `compinit` call per start, 1945 completers registered, `docker` and `just` among them.

#### Left out on purpose

- `home/zsh/zshrc` itself: it is the Mac's (zap installed with `curl` at shell start, `getconf DARWIN_USER_TEMP_DIR`, `~/Library/pnpm`, kubectl, treehouse and aws completions, the todo files).
- Atuin (a history sync server and a login, the Mac's `Ctrl-R` and its fzf picker), zoxide, eza (the Mac's `ls` integration), bat and tmux (the Mac's `programs.*` in `home/default.nix`, not in the shared files). None is installed on the VM; their aliases (`t`, `ta`, `top` for btop, `v` for nvim) stay defined and say `command not found`.
- The Mac's `tmp.zsh` hook is a local file that is not in the repo.

#### Turning the zsh setup off

`dotfiles.agent.zsh.enable = false`: `~/.zshrc` loses all of this, `fzf` goes, and `/etc/zshrc` runs `compinit` again, as before. The completion dump and `~/.zhistory` stay.

### A headless browser for the browser tools

Option `dotfiles.agent.browser.enable`, on when the agent is.

- The `chrome-devtools-axi` skill (`npx -y chrome-devtools-axi open <url>`, `snapshot`, `console`, `screenshot <path>`, `stop`) and omp's `chrome-devtools` MCP server (`home/omp/mcp.json`: `npx -y chrome-devtools-mcp@latest`) both run chrome-devtools-mcp.
- chrome-devtools-mcp starts Chrome itself, when a command needs it, over a pipe (no debug port). On Linux it looks for the stable channel at `/opt/google/chrome/chrome`.
- That path is a link, made by systemd-tmpfiles at boot and at every switch, to the main program (`bin/chromium`) of `pkgs.chromium` of nixos-25.11 (149.0.7827.200; closure 1.69 GiB in 355 store paths, 511 MB to download). It is no system package and on nobody's `PATH`.
- `/opt`, `/opt/google` and `/opt/google/chrome` are root's, 0755 (measured: the user can neither remove nor replace the link, nor add a file beside it).
- Nothing runs while no tool uses it: no service, no socket, no timer, no firewall port.

#### Why a link

Measured.

- chrome-devtools-mcp 1.10.1 has `--executablePath`, but chrome-devtools-axi 0.1.39 cannot pass it: its `CHROME_DEVTOOLS_AXI_CHROME_ARGS` become `--chrome-arg=...`, which go to Chrome, not to the MCP server.
- `CHROME_DEVTOOLS_AXI_MCP_PATH` (a node script that the CLI runs instead of `npx`) does work with a wrapper that adds the flag (measured: first `open` 15 s, `stop` clean). But it needs a variable in every shell and a wrapper file, and it does not reach omp's MCP entry, which is the Mac's file and names no executable.
- The link needs no variable and serves both.

#### Headless and without a GPU

The package is `pkgs.chromium.override { commandLineArgs = "--headless=new --disable-gpu"; }`. Only nixpkgs' small wrapper script changes, the browser itself is the stock one, and `just test-roles` accepts exactly these two flags there and no other.

- `--headless=new`, because the VM has no display and omp's MCP entry (the Mac's, with no `--headless`) would otherwise stop at "Missing X server" (measured).
- `--disable-gpu`, because the VM has no GPU. With the software GL fallback that Chromium then takes, its GPU process runs with no seccomp filter (measured: seccomp 0 in every launch, 2 with the flag). Chromium's own message for that fallback is "Please use the --enable-unsafe-swiftshader (about:flags#enable-unsafe-swiftshader) flag to opt in to lower security guarantees for trusted content" (measured).
- The cost is WebGL: `getContext("webgl")` works without the flag and fails with it (measured directly and through the CLI, three runs each). The sha256 of a screenshot of a plain page is the same with and without the flag (measured).
- To get WebGL back, add `--enable-unsafe-swiftshader` to `commandLineArgs` (and to the exact list that `just test-roles` expects). WebGL works then, and the GPU process is back to seccomp 0 (both measured).

#### The sandbox stays on

Measured on the VM.

- Chromium's user-namespace sandbox works for the user with no setuid helper, no change to a kernel setting and no `--no-sandbox` (the same user namespaces that rootless Docker and podman use).
- In a run: the renderers (4) and the network service run in their own user and pid namespaces with a seccomp filter (`Seccomp: 2`, `NoNewPrivs: 1`), and the GPU process and its broker have the filter.
- None of the 13 browser processes of that run has `--no-sandbox`, `--disable-setuid-sandbox`, `--disable-namespace-sandbox`, `--disable-seccomp-filter-sandbox` or `--disable-gpu-sandbox` on its command line (a scan of `/proc/<pid>/cmdline` with a planted-flag positive control). The browser carries `--remote-debugging-pipe` and no `--remote-debugging-port`.
- Three processes are unsandboxed by Chromium's own design: the browser process, the main zygote (its own flag `--no-zygote-sandbox`: it is the parent that forks the sandboxed ones) and one utility process (`--service-sandbox-type=none`).

`just test-roles` keeps it so:

- It compares every setuid or capability wrapper, kernel setting, tmpfiles rule, unit, socket, timer, package, environment variable, group of the user and sudo entry with the agent with the option off. It accepts exactly three tmpfiles rules and one line of `~/.zshenv` as the difference, whatever the names.
- It finds no flag that turns a sandbox off, no `PUPPETEER_DANGEROUS_NO_SANDBOX` and no `remote-debugging` in the rules, the wrapper, `~/.zshenv` or the environment of the system, the session and Home Manager.
- A scan of `modules/` and `home/` (with a positive control that it reads the two files of the piece) finds no such flag in any source.

After a nixpkgs bump, re-check the GPU process while a browser runs: `for p in $(pgrep -f -- --type=gpu-process); do awk '/^Seccomp:/{print $2}' /proc/$p/status; done` must print `2`.

#### On demand, and stopped by its CLI

- chrome-devtools-axi starts a small bridge (a listener on `127.0.0.1:9224`) and, through chrome-devtools-mcp, the browser at the first command, and keeps both until `stop`.
- The bridge refuses a rebound request (measured: 403 for a Host that is not loopback and for a non-loopback Origin; 200 for a loopback Host with no Origin and for a loopback Origin; 400 with no Host header).
- `~/.zshenv` (read by every zsh: an ssh login, `zsh -c`, the shell of a Tern session, omp's shell) exports `CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS=900000`, next to the Hindsight snippet. So a browser that nobody stopped is stopped by its CLI after 15 minutes without a command (measured with a 6 s timeout: browser, bridge and listener gone 6 s after the last command). It is the only variable of the CLI that is set.
- After `stop`: no chromium or crashpad process, no bridge, no listener on 9224 or 9222.
- omp's MCP server starts the browser at its first tool call and leaves with omp. Unlike the CLI it uses a persistent profile (`~/.cache/chrome-devtools-mcp/chrome-profile`: cookies and logins stay between sessions).
- The MCP entry was driven over stdio with the exact entry of `~/.omp/agent/mcp.json` by a small JSON-RPC client (initialize, tools/list, navigate, snapshot, console, screenshot). omp itself was not run.

#### Cost

Measured.

- A page load of the local test page plus `https://example.com` peaks at 1.4 to 1.6 GiB of resident memory summed over 18 to 20 processes (five runs), 0.7 GiB with shared pages counted once, and the system's available memory dropped by 0.5 GiB (one run each; the VM has 7944 MiB and zram).
- The first `open` with an empty npm cache takes 13 s (one run; the CLI waits 30 s for its bridge by default, `CHROME_DEVTOOLS_AXI_BRIDGE_TIMEOUT_MS`).
- Fonts: DejaVu Sans is the only font on the VM (`fc-list` lists it alone, and `fc-match` gives it for sans-serif, serif, monospace and emoji), so serif and monospace text draws in the sans face. Text in other scripts and emoji will likely draw as boxes (not measured).

#### What it gives the agent

The agent can browse any site that the VM can reach, with the VM's network: the LAN and loopback included. That is what a browser tool is. Do not log in to anything in its profile that you do not want it to use.

#### Off, and flip to clean

- `dotfiles.agent.browser.enable = false` removes the rules and the variable at the next deploy.
- systemd-tmpfiles makes a link but does not remove what a rule that is gone once made (measured on a flip to clean for `/lib64/ld-linux-x86-64.so.2`, see [Agent to clean](#agent-to-clean); not measured for this link, no flip was run). So `/opt/google/chrome/chrome` is expected to stay: root's link to a store path that stays until the generations that name it are deleted and garbage collected.
- `vm-deploy` does not remove it: its removal step runs as the agent user only, never as root. `rm -r /opt/google` as root removes the link.
- A running browser is not stopped by `vm-deploy`, and `vm_unsync` stops only the install units and the Docker service. The CLI's idle timeout ends a browser of the CLI, and omp's end ends one of its MCP server.

### Clean to agent

Set `role` to `agent`, then `just vm-deploy <name>`. Then run `tern remote setup` if you want Tern.

The first deploy builds the module on the VM and fetches omp (about 270 MB), and for the Mason piece neovim, go and the Rust toolchain (1.6 GiB of it): see [Mason language servers for omp](#mason-language-servers-for-omp).

### Agent to clean

Set `role` to `clean`, then `just vm-deploy <name>`.

NixOS removes what the module declares: the services, the packages, the firewall port, zram, the user's entry in the account database and its subuid range.

Measured leftovers:

- The home directory stays, with everything in it:
  - `~/.ssh/authorized_keys` and any key you added there;
  - Tern's binary and state;
  - omp's config;
  - mise's installed tools;
  - the Mason language servers in `~/.local/share/nvim/mason` (see [Mason language servers for omp](#mason-language-servers-for-omp));
  - podman's images;
  - Docker's images, containers and volumes in `~/.local/share/docker`;
  - the Docker contexts in `~/.docker`;
  - the key that the VM made for the jumphost (`~/.ssh/id_ed25519_jumphost`; its authorized line on the jumphost stays too until you remove it);
  - Home Manager's links, which dangle after a garbage collection.
- The user's uid stays reserved, so the user comes back with the same uid and finds its home.
- `/lib64/ld-linux-x86-64.so.2` stays as a link into the store (it is a tmpfiles link, harmless).
- The rootless Docker service is stopped by `vm-deploy` before the switch (see [Docker](#docker-rootless-only-with-compose)), so no daemon or container runs on.
- Tern's service and the user's manager keep running as the removed user until `systemctl stop user@<uid>.service` or the next boot. The firewall has closed the port at once, and nothing restarts them after a reboot.

Expected, not measured (no flip was run):

- The browser link `/opt/google/chrome/chrome` stays the same way (root's, a link into a 1.69 GiB closure; see [A headless browser for the browser tools](#a-headless-browser-for-the-browser-tools)).
- A browser that is running at the flip keeps running as the removed user like Tern's service, until the CLI's idle timeout or omp's end stops it.

Flipping back to `agent` works: the user, linger, the services and Tern's service return, and the Mac's host entry works again without a new setup. A truly clean VM needs a reinstall with role `clean`.

### Personal setup: Hindsight, plugins, skills

- Options `dotfiles.agent.sync.hindsight`, `.plugins` and `.skills`, each on when the agent is. The VM lists them in `/etc/dotfiles-agent-sync.json`, which `just vm-sync <name>` reads.
- `just vm-deploy <name>` runs `vm-sync` after an agent deploy. When that sync fails or is refused, the deploy has still happened and exits 1: fix the cause, then `just vm-sync <name>`.
- `~/.omp/.env` is **not** synced, in any form: it holds the API keys, so put it in place by hand.
- `just vm-sync` itself runs on the Mac and is for the agent role only. Everything it runs on the VM is the agent user's (`infra/vm-sync-remote.sh`, sent over ssh), never root's.

#### Host keys

- Every connection of `vm-sync` (ssh and rsync) uses `StrictHostKeyChecking=yes` and `UpdateHostKeys=no`.
- The VM's key must already be pinned in `~/.ssh/known_hosts`. Otherwise `vm-sync` refuses before it sends anything and says so, naming the re-key step of [Reinstall](#reinstall): `ssh-keygen -R <ipv4>`, then connect once, or `just vm-deploy <name>`, which trusts a key on first use as it always did.
- The VM's console has no login, so there is no second channel to compare a fingerprint with: what you check is that the address belongs to the VM.
- `vm-install` is unchanged.
- `vm-deploy` takes the answer before its switch (the switch itself may pin a new key):
  - an agent deploy over a key that was not pinned before it (or that could not be probed) still deploys, does not sync, and exits 1 with that message;
  - a clean deploy over an unpinned key skips the removal described under [Flip to clean: removing what the sync placed](#flip-to-clean-removing-what-the-sync-placed), because nothing can be verified over such a key (files that a sync from another Mac, or from before the key was cleared, put into `/home/lex` stay there: pin the key and flip to `agent` and back to remove them);
  - a key that does not match stops it before anything is changed.

#### gh login is manual

- Log in on the VM with `gh auth login`. The CLI and git's credential helper for `github.com` and `gist.github.com` (Home Manager) are installed, and nothing in this repo or in the vault holds a GitHub token.
- gh keeps its login and config in `~/.config/gh`, which nothing here manages (a plain directory that gh writes itself). So no deploy, sync, reboot or role flip overwrites or deletes it. Switching to clean leaves it in `/home/lex`.

#### The omp .env file

`~/.omp/.env` is manual too. It holds the model API keys and nothing here copies it.

- On the Mac it is written from the vault blob `OMP_ENV` (`just home` pulls it; `just secretspec-sync` pushes an edit).
- The VM needs only the providers it can reach (see [omp](#omp)). Make a private file with just those lines, outside the repo, then put it in place over ssh. That keeps it off the terminal and out of argv, and `umask 077` makes it mode 600:

```bash
ssh <user>@<ipv4> 'umask 077 && mkdir -p ~/.omp && cat > ~/.omp/.env' < <your prepared file>
```

omp reads it at its next start. A reinstall deletes it.

#### Plugins

- `just omp-plugins-capture` (on the Mac) copies `package.json`, `bun.lock` and `omp-plugins.lock.json` from `~/.omp/plugins` to `home/omp/plugins/` (`home/omp/plugins-capture.sh`).
- It writes nothing and exits 1 when a file holds a token, a URL, an absolute path, a local or git source (`file:`, `link:`, `workspace:`, `github:`, `git+...`) or a registry other than the default, since the files are public and the VM has no `.npmrc`.
- The lock file may hold nothing but what omp writes (per plugin a version, `enabled` and `enabledFeatures`; empty `settings`). A free-form value, such as a plugin's own key, matches no token shape, so anything else is refused.
- It drops lock entries of plugins that are not dependencies (stale), and sets each lock version to the one installed on disk (otherwise `omp plugin doctor` reports lock drift as an error).
- `node_modules` is never copied: it holds the Mac's native binaries, and `bun install` resolves the Linux ones from `bun.lock`.
- The three files are placed in `~/.omp/plugins` as writable files (omp rewrites them; same rules as the omp config above, see [Config](#config)).
- The user service `omp-plugins-install` runs `bun install --frozen-lockfile` there when their hash is new. The stamp is `~/.local/state/dotfiles/omp-plugins.stamp`, written only after a successful install, so a failure is retried: up to 5 times an hour, and at the next boot.
- It is `Type=simple`, so a deploy does not wait for the first install (about a gigabyte). Follow it with `journalctl --user -u omp-plugins-install`.
- bun's download cache lives in `~/.omp/plugins/.bun-cache` and is removed after each run.
- bun, node and `harper-cli` (which `pi-harper-grammar` runs) come from nixpkgs-unstable: nixos-25.11's `harper` builds `harper-ls` only.
- Plugins installed by hand on the VM (`omp plugin install`) change `package.json` there and stay until a new capture replaces it (the old file is kept as `.dotfiles-backup`).

#### Skills

- `vm-sync` mirrors every directory of `~/.skills-manager/skills` that holds a `SKILL.md` (not hidden, not a link) into `~/.omp/agent/skills` with rsync, one directory at a time, exactly inside it (`--delete` there and nowhere else).
- Nothing else in `~/.omp/agent/skills` is touched or deleted.
- `~/.omp/agent/managed-skills` (the auto-learned store, with infra notes) is never read, copied or listed: a source path or a library member that resolves to a `managed-skills` path is refused.
- No skill is in this repo.

#### Flip to clean: removing what the sync placed

Before the switch, `vm-deploy` runs the removal as the agent user.

- Exactly what the sync placed goes: the files and skill directories the sync recorded in `~/.local/state/dotfiles/vm-sync/manifest` (including the Hindsight file), and the plugin install `~/.omp/plugins` as one directory with its install stamp and the records of its three files.
- A file of yours that the sync displaced (`hindsight.env`) comes back, and directories the sync made are removed while empty.
- The helper acts only on the few entries the sync records (an edited manifest cannot point it at another file).
- If a removal fails, the helper says which, exits 1 and keeps the manifest and the records for a retry, and the deploy stops before the role changes.
- If the switch itself then fails, the synced files are already gone: `vm-deploy` says so. Fix the cause and run `just vm-deploy <name>` again (to stay an agent, set the role back to `agent` first: that deploy syncs again).
- Nothing else in the home changes (omp's config, `~/.omp/.env`, `~/.config/gh`, anything you made). A plugin you installed by hand into `~/.omp/plugins` goes with that directory.
- Flipping back to `agent` places everything again (the plugin install downloads again).

### Hindsight

- The LAN address in the committed omp config cannot be reached from the VM. The public Hindsight API sits behind an API-key gate instead (header `Authorization: Bearer <key>`: 200 with a good key, 401 with none or a wrong one).
- omp reads `HINDSIGHT_API_URL` and `HINDSIGHT_API_TOKEN` from the environment before `config.yml`. Measured on the VM with omp 18.8.6 against a fake server: the URL and key of the environment won over `hindsight.apiUrl`. So the sync sets those two variables and touches neither `~/.omp/.env` nor `config.yml`.
- There is one entry per VM and one key per VM (so that it can be revoked alone). You store them in the `dotfiles-infra` project as the JSON map `VM_HINDSIGHT` (VM name to `{"url": "https://…", "token": "…"}`; optional, the manifest default is `{}`).
- Store one without the key reaching a command line or the shell history: `read -rs key; secretspec get VM_HINDSIGHT | KEY=$key U=<url> jq -c --arg n <name> '. + {($n): {url: env.U, token: env.KEY}}' | secretspec set VM_HINDSIGHT; unset key`. The pipe keeps the old map off the terminal; never run `secretspec get` with its output on the terminal.

#### What `vm-sync` does for Hindsight

1. On the Mac, `infra/vm-hindsight-health.py` sends `GET <url>/health` with the key (verified TLS, no proxy, no redirect followed, URL and key on stdin only). Anything but 200 stops the sync with a message and writes nothing for this piece (a file that is already there stays as it was).
2. It writes `~/.config/dotfiles/hindsight.env` for the agent user over ssh stdin: mode 600, its directory 700, the URL and the key as two `NAME='value'` lines under a comment that says vm-sync wrote it.
3. The `.zshenv` of Home Manager exports both (`set -a`) in every zsh: the ssh login shell, `ssh host command` and Tern sessions. A process that is not started by zsh (a systemd user unit) does not see them.

With no entry for the VM, the file is removed and `vm-sync` prints one line (`hindsight: no entry for <name> in VM_HINDSIGHT, removed …`). A file of that name that vm-sync did not write is left alone. The flip to clean removes the file.

#### Revoking or rotating a VM's Hindsight key

The same key lives in two OpenBao places:

- the property of that client in `secret/apps/hindsight-api-keys` (an ExternalSecret copies it into the cluster about every minute, then Envoy takes a few seconds);
- the VM's entry in `VM_HINDSIGHT`.

Every `bao` command here needs `export BAO_ADDR=https://openbao.home.0dl.me` and a token from `just openbao-login` (`bao` reads `~/.vault-token`). The client's property is named `vm-<name>` after the VM.

Revoke:

1. `bao kv metadata get -mount=secret apps/hindsight-api-keys`, and find the newest version `<V0>` that does not hold the VM's property and with no other property added after it.
2. `bao kv rollback -mount=secret -version=<V0> apps/hindsight-api-keys`. Never `bao kv put` with a partial set. If another client's key was added after `<V0>` the rollback would delete it; then read the set into a mode-600 file, drop the one property and put the rest back from the file (untested).
3. Wait up to a minute and a few seconds. Then `GET /health` with the old key must be 401 while the other clients' keys still give 200.
4. Optionally `bao kv destroy -mount=secret -versions=<versions that held it> apps/hindsight-api-keys`.
5. Remove or replace the VM's entry in `VM_HINDSIGHT` (the next `vm-sync` then removes the file, or writes the new key after its health check).

Mint a key: `umask 077; openssl rand -hex 24 | tr -d '\n' > <key file>`, then `bao kv patch -mount=secret apps/hindsight-api-keys vm-<name>=- < <key file>` (patch, never put; the key comes from stdin and has no newline). The same file feeds `VM_HINDSIGHT`: use `read -r key < <key file>` in place of the `read -rs key` above, then delete the file.

Rotate: add the new property, update `VM_HINDSIGHT`, run `just vm-sync <name>`, then revoke the old property as above (the gate must answer 401 for it).

#### Hindsight: residual risks

- The key is in the environment of every shell and process of the agent user and in a mode-600 file. Anything that runs as that user can read it (so can its other processes through `/proc`).
- The gate does not name the client in its access log, and nothing here verifies per-key scoping inside Hindsight: assume every key has the same access.
- Cloudflare's 100 second limit can cut a long reflect call.
- With per-project tagged scoping, the VM's projects can be tagged differently from the Mac's paths, so memories from the VM land under other tags.

### Mason language servers for omp

Option `dotfiles.agent.mason.enable`, on when the agent is. It is not a sync piece: no `vm-sync`, nothing in `/etc/dotfiles-agent-sync.json`, and the sync options do not switch it.

- omp's LSP tool starts a server when the server's command is on its `PATH`. The captured plugin `pi-mason-bridge` puts `~/.local/share/nvim/mason/bin` on omp's `PATH`. Measured in its installed source: it prepends `$MASON/bin` (default that directory) once when a session loads its extensions, before omp resolves its LSP config, and does nothing when the directory is missing. So a session that started before the first install has to be restarted to see the servers.
- The VM gets that directory from a minimal Neovim: `pkgs.neovim` (0.11.7) and `pkgs.vimPlugins.mason-nvim` (2025-11-14) of nixos-25.11, an init file in the Nix store (`home/linux/mason-init.lua`) that sets the runtime path to mason.nvim and Neovim's own runtime and loads mason.nvim and nothing else, and a user service.
- Nothing else of Neovim comes with it:
  - no `~/.config/nvim` is created, read or changed (the init file does not read it, and `just test-roles` pins that);
  - no other plugin;
  - no Mason package outside the LSP category (so no formatter, linter or debugger of Mason). The one tool from outside Mason, by decision, is `shellcheck` from nixpkgs on lex's login `PATH`, for the diagnostics of `bash-language-server`;
  - Neovim is on no `PATH` (the unit names it by store path).

#### Capture

`just mason-capture` (on the Mac) reads `~/.local/share/nvim/mason`: the receipt of each installed package (`packages/<name>/mason-receipt.json`, which Mason writes when an install is finished) and the registry (`registries/github/mason-org/mason-registry/registry.json`) for the categories. It writes `home/omp/mason-lsp.txt` (`home/omp/mason-capture.sh`): package names, sorted, one per line, and nothing else (no version, no path).

- A package is in when it is in Mason's LSP category, one of the executables it links is, letter for letter, the command of one of the 55 built-in servers of omp 18.8.7 (`home/omp/lsp-builtins.txt`), and it is not in `home/omp/mason-lsp-skip.txt` (`<package>  <reason>` per line).
- omp has no command that lists its built-in servers, so `home/omp/lsp-builtins-extract.sh <omp binary>` reads the table out of the compiled binary, where it is JavaScript text. Run it again after an omp bump: `just test-infra` fails while the version in the first line of `lsp-builtins.txt` differs from the one in `modules/nixos/agent-dev/omp.nix`.
- The capture refuses (exit 1, nothing written) a name that is not a plain package name (`[a-z0-9][a-z0-9._-]*`, which every one of the 600 registry names is), a receipt that names another package than its directory, a registry that is not a list of packages, and an empty result. It prints what it left out and why.
- Mason installs the registry's current version of a package on the VM, like mise's `latest`; the list carries no version.
- Review `git diff`, commit, then `just vm-deploy <name>`.

#### The servers (19)

`bash-language-server`, `biome`, `css-lsp`, `dockerfile-language-server`, `emmet-language-server`, `gopls`, `helm-ls`, `html-lsp`, `json-lsp`, `lua-language-server`, `marksman`, `nil`, `pyright`, `ruff`, `rust-analyzer`, `svelte-language-server`, `tailwindcss-language-server`, `vue-language-server`, `yaml-language-server`.

- `biome` and `ruff` are in Mason's LSP category and omp has servers for them (it treats them as linter servers), so the rule takes them. Drop one by adding it to the skip list.
- omp starts a server in a project directory only when one of the server's root markers is in that directory (`go.mod` for gopls, `Cargo.toml` for rust-analyzer, `pyproject.toml` for pyright, `.git` for bash-language-server and yaml-language-server, and so on; measured in the binary).
- A server that works through its language's tools (gopls: go, the npm servers: node, rust-analyzer: cargo) finds them in mise at run time.

Measured on the VM with omp 18.8.6, the real plugin discovery and a throwaway project per server:

- omp's `lsp` status lists the server of every project with the bridge on, and none of the Mason servers with `omp plugin disable pi-mason-bridge`. Re-enabled: the same lists again. omp rewrites the plugin lock file when it is toggled, with the same plugins and flags and without the final newline of the repo copy, which `writable-copy` keeps as it is.
- All 19 answer an LSP `initialize` over stdio.
- Diagnostics of a deliberate error come back for gopls, pyright, ruff, rust-analyzer, biome, yaml, lua, marksman, dockerfile, svelte and nil.

The Mac gives the same picture with the same projects. The differences: rust-analyzer's error came back on the VM only, svelte's call was aborted on the Mac only, and bash-language-server's diagnostics came back on the Mac only until the role installed `shellcheck`.

- `vue-language-server`, `helm-ls` and `emmet-language-server` end with "Operation aborted" on both.
- `json-lsp`, `css-lsp`, `html-lsp` and `tailwindcss-language-server` answer "OK" without a diagnostic on both. So for those four the proof is the `initialize` answer and the status listing only.
- `bash-language-server` takes its diagnostics from `shellcheck`: the option puts `shellcheck` (nixpkgs, 0.11.0) on lex's login PATH, which omp inherits, and not on the PATH of the install unit. Mason's own `shellcheck` is a linter and is not captured.

#### Skipped, with the reason

These are in `home/omp/mason-lsp-skip.txt` (measured on the VM):

- `elixir-ls` installs (a zip of shell scripts) but its launch script stops with `command not found: elixir` (Erlang/OTP and Elixir are not on the VM).
- `omnisharp` is the .NET build, which stops with `exec: dotnet: not found`. Mason links it as `OmniSharp` while omp looks for `omnisharp`, which the Mac's case-insensitive disk hides and Linux does not.
- `astro-language-server` answers `initialize` only when given the init option `typescript.tsdk`, which omp does not send. So omp reports "all language servers failed (astro)" on the VM and on the Mac alike. A project's `.omp/lsp.json` can set `servers.astro.initOptions.typescript.tsdk`, then install the server by hand: the same headless command as the service, with `MasonInstall` instead. The service never uninstalls, and never puts back what you removed while the list is the same.

A server that was installed before it went on the skip list stays on omp's `PATH` until you remove it:

- `MASON_NVIM=<mason.nvim> <nvim> --headless -u <init.lua> -i NONE --noplugin "+MasonUninstall <name>" +qa`, where the three store paths are in `systemctl --user cat mason-lsp-install` (`MasonUninstall` blocks and exits 0; measured);
- or delete `~/.local/share/nvim/mason/packages/<name>` and its link in `~/.local/share/nvim/mason/bin`.

The first deploy after astro left the list needed this once on the VM.

#### Mason servers that omp has no built-in server for are not used

`docker-compose-language-service`, `harper-ls` (the VM's grammar checks use the `harper-cli` of the plugin `pi-harper-grammar`), `htmx-lsp`, `lemminx`, `stylua`, `taplo`, `templ`, `tflint` and `vtsls`. omp would never start them, so the capture leaves them out and says so.

#### The install service

The user service `mason-lsp-install` (`home/linux/mason-lsp-install.sh`):

- It has `Type=simple`, so a deploy does not wait for the first install (about 900 MB downloaded and unpacked, 100 s on the VM). It is wanted by `default.target`, and is retried after a failure (60 s apart, five times an hour, and again at the next boot), like the plugin install.
- The hash of `mason-lsp.txt` is part of the unit, so a changed list restarts it at the next deploy. A stamp (`~/.local/state/dotfiles/mason-lsp.stamp`) written only when every package is there keeps a boot with nothing new from installing anything.
- Only packages with no receipt are installed, each by its own `nvim --headless -u <init.lua> -i NONE --noplugin "+MasonInstall <name>" +qa`. In headless mode `MasonInstall` waits until the install is done and makes nvim exit with status 1 when it failed (read in mason.nvim's `lua/mason/api/command.lua` and measured). A package the registry no longer has aborts that run with status 1, and one failing package must not hide the others, so the receipt of each package is checked after its run as well.
- Nothing is ever uninstalled: a server that you install by hand with Mason stays, and so does one that dropped out of the list.
- `journalctl --user -u mason-lsp-install` shows what it did. After five failed starts within an hour the unit rests until the next boot; `systemctl --user reset-failed mason-lsp-install && systemctl --user start mason-lsp-install` tries again.
- A session of omp that started before the install finished has to be restarted.
- A listed server that you remove by hand is not put back while the list is the same (the stamp matches), but a wiped `packages` directory is rebuilt, as the plugin install rebuilds a missing `node_modules`.
- The service writes under `~/.local/share/nvim/mason` (Mason's data, where the bridge looks), `~/.local/state/nvim` (its two log files) and `~/.local/state/dotfiles` (the stamp).
- npm, go and cargo caches, nvim's own cache and go's telemetry file go to a work directory under `~/.cache/dotfiles` (through `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `npm_config_cache`, `GOPATH`, `CARGO_HOME`). It is removed at the end, also after a failure and also when a killed run left one: they were about 900 MB.

#### The PATH of the install service

It is exactly what the installs of the listed servers run. Measured by installing all of them with that `PATH` and by taking away, one at a time, `curl`, `gzip`, `tar`, `getconf`, node and go:

- `curl`: registry and release assets. Without it `MasonInstall` says the package is not valid.
- `gzip` and `tar`: `rust-analyzer` is a `.gz`, `ruff` is a `.tar.gz`.
- `getconf`: Mason takes `getconf`, then `ldd`, to tell glibc from musl, and without either it calls NixOS an unsupported platform (`rust-analyzer`, `lua-language-server` and `helm-ls`).
- node with npm (12 packages).
- go (`gopls`): gopls 0.23 needs Go 1.26 and nixos-25.11 has 1.25, so go downloads go1.26.9 into the work directory at each install (`GOTOOLCHAIN=auto`).
- For `nil`, which Mason builds from a git tag: `cargo` with `rustc`, a C compiler, `git` and `nix`. The build ran with those five together, and without `nix` it fails ("Is `nix` accessible?", its build script runs it). The other four are cargo's own requirements and were not taken away one at a time.
- `bash` and `coreutils` are for the script itself.

Not needed, measured: `unzip` (no package of the list is a zip; Mason refreshes its registry without it), python and its venv (no package of the list comes from PyPI), a second compiler.

The Rust toolchain is the cost of `nil`: `rustc` and `cargo` are 1.6 GiB of closure (the VM's system closure was 3.1 GiB).

- A later `just mason-capture` refuses a package whose source (`pkg:pypi`, `pkg:gem`, `pkg:nuget`, ...) this `PATH` has no tool for, and names it. Skip it, or grow `toolPackages` and the expected list in `infra/roles-check.sh` first. A `pkg:github` package whose Linux asset is a `.zip` or `.tar.xz` needs `unzip` or `xz`, which the capture cannot see.
- To drop `nil`: add `nil  <reason>` to `home/omp/mason-lsp-skip.txt`, run `just mason-capture`, and take `pkgs.cargo`, `pkgs.rustc`, `pkgs.gcc`, `pkgs.git` and `pkgs.nix` out of `toolPackages` in `modules/nixos/agent-dev.nix` and out of the expected list in `infra/roles-check.sh`.

#### Flip to clean: the Mason data stays

- `vm-deploy` leaves `~/.local/share/nvim/mason` and the stamp where they are, and says nothing about them.
- It is the data directory of any Neovim, and a Neovim config that you may put in `~/.config/nvim` later would use it.
- Unlike `~/.omp/plugins` (which only the plugin install fills, and which the removal recognises by the records of the files placed there), nothing records which files in it are the service's. So removing the directory could remove what you installed by hand.
- It is listed with the other leftovers under [Agent to clean](#agent-to-clean). A flip back to agent finds the packages there and installs nothing.
- `vm-deploy` does stop a running install before the switch, as it does for the plugin install, so that none goes on as the removed user.

## Identity: fixed at install

NixOS runs no cloud-init (the module is off and the package is not in the system closure). So nothing on a cloud-init drive (user data, scripts, boothooks, part handlers) can act on the VM. The Proxmox drive only serves the Debian bootstrap stage.

`vm-install` writes the identity into the new system from the VM's `TF_VAR_vms` entry, after checking each value (they end up inside a unit file):

- `/etc/hostname` (the name);
- `/etc/systemd/network/10-static.network`: `[Match] MACAddress=<mac>`, so the NIC's name does not matter; `[Network]` `Address=<ipv4>/<prefix>`, `Gateway=<gateway>`, one `DNS=<resolver>` per entry of `dns`;
- for the initrd, `/etc/secrets/initrd/10-initrd.network`.

NixOS leaves the first two alone: the role sets no `hostName` (do not set one: NixOS would replace `/etc/hostname` with a symlink) and defines no networkd unit.

### What a change of the entry does

- Changing `ipv4_cidr`, `gateway` or `dns` in `TF_VAR_vms`, or `ipconfig0`, `nameserver` or `sshkeys` on the Proxmox VM, does not change the running VM, also not across a reboot. The drive stays attached and OpenTofu keeps maintaining it for the Debian stage; NixOS never reads it. Measured: a throwaway key set as `sshkeys` and a different unused `ipconfig0` reached the drive and had no effect on the guest.
- `mac` is different. It is the NIC's hardware address (`network_device`), and both network files match on it, so applying a new one should leave the next boot without network, not even in the initrd (expected from the match; not measured). Reinstall for a MAC change, or put the new `MACAddress=` into both files (steps 1 and 2 of [Change the address, gateway or resolver](#change-the-address-gateway-or-resolver)) before you apply it. That variant was not exercised.
- There is no search domain. A search domain that the Proxmox host's resolver settings put on the drive is not carried over (it never came from the VM entry); names resolve with their full domain.

### Change the address, gateway or resolver

Do this in the order below. The VM stays reachable at its old address until step 3. `vm-deploy` and `vm-unlock` read the address from the OpenTofu state, which follows `TF_VAR_vms` only after `just infra-apply`.

1. As root over SSH, edit the `Address=`, `Gateway=` and `DNS=` lines of `/etc/systemd/network/10-static.network` and `/etc/secrets/initrd/10-initrd.network`. Keep mode 0644.
2. `just vm-deploy <name>`: it rewrites the initrd from the edited initrd file. Nothing reloads networkd, so the running address does not change.
3. `reboot` on the VM.
4. Change the entry in `TF_VAR_vms`, then `just infra-plan` and `just infra-apply` (only the drive changes; the provider may reboot the VM, which then waits in the initrd).
5. `just vm-unlock <name>`.

If the VM is not reachable afterwards, type the passphrase on the serial console and see [Recovery](#recovery). This sequence was not exercised as a whole; the two files and the reboot and unlock path were.

### Change the name

To change the name, reinstall. The entry's key is the Proxmox VM name, the hostname and the key of both vault maps, and OpenTofu replaces the VM when the key changes: [Remove a VM](#remove-a-vm), then [Add a VM](#add-a-vm) with the new name (the new name gets a new disk passphrase). Editing `/etc/hostname` alone renames only the guest and leaves it out of step with its entry.

### A VM installed with an earlier version of the role

A VM installed with an earlier version of this role (cloud-init on NixOS) must be reinstalled before `vm-deploy` of the current role. It has no `10-static.network` (its network came from cloud-init, which the current role removes), so it would come up without network at the next reboot.

If you do not want to reinstall, write `/etc/hostname` and `/etc/systemd/network/10-static.network` by hand first, with the content described above. Mind that the initrd file (`/etc/secrets/initrd/10-initrd.network`) already exists from that install.

## Disk encryption and unlock

The disk has:

- a BIOS boot partition;
- an unencrypted 1 GiB ext4 `/boot` (kernel, initrd, initrd secrets; GRUB on SeaBIOS never touches LUKS);
- a LUKS2 root (`cryptroot`, `aes-xts-plain64`; TRIM is not passed through, because it would show which blocks are free).

GRUB keeps 5 generations so `/boot` cannot fill up.

### Passphrases and host keys

- `VM_LUKS_KEYS` maps `<name>` to a generated 64-hex-digit passphrase. `vm-install` creates it on the first install of a name and keeps it across reinstalls. It writes it to OpenBao before the disk is touched and passes it to the installer as a file in a 0700 temp directory (`nixos-anywhere --disk-encryption-keys`).
- `VM_INITRD_HOST_KEYS` maps `<name>` to the public key of the initrd's SSH host key. Every install makes a fresh key pair and stores the public half first.
- Both maps are updated by read-modify-write, and the entries are checked again right before the disk is formatted. But run one `vm-install` at a time: two at once can overwrite each other's entry.

### What the initrd gets

- The initrd runs systemd with networkd and an SSH server on port 2222.
- Its static address, its SSH host key and its authorized keys are not in the repo or the Nix store. `vm-install` places them on the new system (`nixos-anywhere --extra-files`): `/etc/secrets/initrd/10-initrd.network` (MAC, address and gateway of the VM entry), `/etc/secrets/initrd/ssh_host_ed25519_key`, and `/root/.ssh/authorized_keys` (the key list from `TF_VAR_ssh_authorized_keys`, also root's key list in stage 2).
- The bootloader step (`boot.initrd.secrets`) copies them into the initrd, which sits on the unencrypted `/boot`.
- The initrd's address is cleared before switch-root, so stage 2 configures the NIC from scratch from its own file.
- The initrd's address is the third identity file (see [Identity: fixed at install](#identity-fixed-at-install)): it is written at install and neither `vm-deploy` nor a change of `TF_VAR_vms` touches it.

### Unlocking: every boot waits

After `vm-install`, a reboot, or a restart of the Proxmox host (`on_boot`), the VM stops in the initrd until the passphrase arrives. Nothing unlocks it unattended, by design.

`just vm-unlock <name>`:

- connects to port 2222 with the pinned host key (a throwaway `known_hosts`, strict checking; a mismatch aborts and is never retried);
- finds the pending passphrase query and answers it with `systemd-reply-password`. The passphrase goes over a pipe (not argv, no tty, nothing echoed);
- retries for up to `VM_UNLOCK_TIMEOUT` seconds (default 300) while no query is pending, then waits up to `VM_UNLOCK_BOOT_TIMEOUT` seconds (default 120) for port 22;
- treats port 2222 still being open 45 s after the answer as a refusal: the initrd asked again, so the passphrase was refused;
- exits at once, with nothing sent, when the VM already answers on port 22 and not on 2222.

### Console fallback

- `qm terminal <vmid>` on `<node>` shows the prompt `Please enter passphrase for disk cryptroot:`. Type the passphrase there (read it with `secretspec get VM_LUKS_KEYS | jq -r '.["<name>"]'` in a terminal you trust).
- An empty Enter counts as one of the three tries.
- Root has no password, so the console cannot log in.
- This works when the initrd's network does not, for example after the VM's address changed.

### Sizing and growing the disk

- LUKS2 derives the key with Argon2id, and cryptsetup peaked at 1 GiB of memory at unlock (measured on a 4096 MB VM). Keep `memory_mb` at 2048 or more, as the installer already needs (see [Add a VM](#add-a-vm)).
- A larger `disk_gb` later enlarges the virtual disk only: NixOS runs no growpart or resizefs (there is no cloud-init), and the root is a LUKS partition anyway.
- The manual way is `growpart /dev/sda 3`, `cryptsetup resize cryptroot` and `resize2fs /dev/mapper/cryptroot` on the VM. It was not exercised.

### Limits of the encryption

So nobody over-reads this: it protects the data on the disk image, its snapshots and backups. It does not protect against:

- someone who can change `/boot` (they can replace the initrd with one that records the passphrase you type, and the initrd's SSH host key is readable there);
- a hypervisor administrator who can read the VM's memory or attach boot media;
- losing the passphrase: it is the only way to unlock, so no copy of it (in OpenBao, or offline: see [Offline copies](#offline-copies)) means no data.

The user-data path is closed: NixOS runs no cloud-init, so nothing a Proxmox user can put on the cloud-init drive (a custom `cicustom` snippet included) can run at boot.

## Offline copies

OpenBao holds the only copy of three values of this stack, and no recipe makes another. You make the copy by hand, once, and again when a value changes.

### What to copy

- `VM_LUKS_KEYS`: the disk passphrase of each VM. Lost, the data of every VM is gone (one keyslot, no header backup). The console fallback and `vm-unlock` read it from the vault too, so with OpenBao down a rebooted VM stays locked. With the copy, `jq -r '.["<name>"]' <offline path>/vm-luks-keys.json` prints the passphrase to type on the console (run it in a terminal you trust).
- `TF_VAR_tofu_state_passphrase`: lost, the state object and every backup of it are unreadable ([The object no longer decrypts](#the-object-no-longer-decrypts)).
- `VM_INITRD_HOST_KEYS`: public keys, so no data is at stake. Lost, `vm-unlock` has no key to pin and stops. Unlock on the console, then put the key back (not exercised): `ssh root@<ipv4> 'ssh-keygen -y -f /etc/secrets/initrd/ssh_host_ed25519_key' | cut -d ' ' -f 1,2` prints it (`cut` drops the comment that `-y` adds), and `secretspec get VM_INITRD_HOST_KEYS | jq -c --arg n "<name>" --arg k "<public key>" '. + {($n): $k}' | secretspec set VM_INITRD_HOST_KEYS` stores it.

### Make the copies

Make the copies on encrypted or offline media, never in the repo or in a synced folder: the files hold the secrets in clear. The redirects keep the values off the terminal, and `umask 077` makes the files private (same exported environment as in [secretspec conventions](#secretspec-conventions)):

```bash
umask 077
secretspec get VM_LUKS_KEYS > <offline path>/vm-luks-keys.json
secretspec get TF_VAR_tofu_state_passphrase > <offline path>/tofu-state-passphrase.txt
secretspec get VM_INITRD_HOST_KEYS > <offline path>/vm-initrd-host-keys.json
```

### Check a copy

Check a copy without showing it: `secretspec get VM_LUKS_KEYS | shasum -a 256 | cut -c1-12` and `shasum -a 256 < <offline path>/vm-luks-keys.json | cut -c1-12` must print the same twelve characters.

### Restore from a copy

Restore from stdin: the value comes back unchanged (see [secretspec conventions](#secretspec-conventions)). `VM_LUKS_KEYS` must hold the passphrase the disk was formatted with; `vm-install` keeps an existing entry:

```bash
secretspec set VM_LUKS_KEYS < <offline path>/vm-luks-keys.json
secretspec set TF_VAR_tofu_state_passphrase < <offline path>/tofu-state-passphrase.txt
secretspec set VM_INITRD_HOST_KEYS < <offline path>/vm-initrd-host-keys.json
```

## Recovery

### Unreachable after boot

- Use the serial console: `qm terminal <vmid>` on `<node>`.
- If the VM sits at `Please enter passphrase`, run `just vm-unlock <name>`, or type the passphrase there.
- At the GRUB menu (serial too) pick an older generation to roll back a kernel or role problem, then fix the role and `just vm-deploy <name>`. That does not help with the identity files (next section).

### Stage 2 has no network, or the identity files are wrong

This happens after a NIC or MAC change, or when the identity files are wrong. The initrd still answers if its own file is right and the console prompt always works, but root cannot log in on the console.

GRUB's older generations do not help, because `/etc/hostname` and `/etc/systemd/network/10-static.network` belong to no generation, and no generation has cloud-init to bring the network back (it is not installed on NixOS). So either:

- reinstall ([Reinstall](#reinstall)); or
- boot a rescue image from Proxmox (attach an ISO, boot it), open the volume (`cryptsetup open /dev/disk/by-partlabel/disk-main-root cryptroot`, with the passphrase), mount it, fix the two files (mode 0644), unmount, close and boot again. The rescue path was not exercised.

### vm-unlock stops with a host key error

The initrd at that address does not present the key `vm-install` pinned. `vm-unlock` never retries. Check that the address belongs to `<name>`, then use the console. A reinstall pins a new key.

### Reinstall

Recreate the VM, clear its old host key, wait for Debian to boot, then install again and unlock.

- The recreated Debian has a new host key. Without `ssh-keygen -R`, the `vm-install` guard refuses the changed key (its message names this cause, next to "still booting" and "already NixOS").
- The disk passphrase of `<name>` is kept; the initrd host key is new.
- A reinstall formats the disk: everything in the VM's home is gone (the `~/.omp/.env`, the `gh` login, Tern, mise's tools, containers). The repo and the vault hold the rest.

```bash
just infra-apply "-replace='proxmox_virtual_environment_vm.vm[\"<name>\"]'"
ssh-keygen -R <ipv4>
just vm-install <name>
just vm-unlock <name>
```

A new VM also has new keys, and what holds the old ones needs a step each. For the role `agent`:

#### Pin the new host key, then deploy

Run `ssh root@<ipv4> true`. The VM's console has no login, so what you check is that the address belongs to the VM. Then run `just vm-deploy <name>`. The install itself syncs nothing (Hindsight file, skills, plugins); the deploy does.

#### Jumphost: remove the old key's line

- `just vm-jumphost-authorize <name>` (and `… <name> shell`) appends the new key's line next to the old one (both carry the comment `<name> docker-jumphost`, or `<name> shell-jumphost`) and never removes a line. So the old key stays valid until you delete its line. Do it for each key that the old VM had authorized.
- The authorize script prints the new key's fingerprint.
- List the fingerprints on the jumphost, then delete the old line by its fingerprint with the script below. Without the old VM, the old key is the other line with the same comment.
- The removal script backs the file up first (`authorized_keys.bak-<timestamp>`), deletes exactly one line, and stops without a change when the fingerprint matches no line or several. Never give it the new fingerprint.

```bash
ssh jumphost_server 'ssh-keygen -l -f ~/.ssh/authorized_keys'    # one line per key, with its comment
old='SHA256:<fingerprint of the old key>'
ssh jumphost_server "OLD='$old' sh -s" <<'EOF'
set -eu
ak=$HOME/.ssh/authorized_keys
cp -p "$ak" "$ak.bak-$(date -u +%Y%m%dT%H%M%SZ)"
tmp=$(mktemp "$HOME/.ssh/authorized_keys.new.XXXXXX")
n=0
while IFS= read -r line || [ -n "$line" ]; do
  fp=$(printf '%s\n' "$line" | ssh-keygen -l -f - 2>/dev/null | awk '{print $2}') || fp=
  if [ -n "$fp" ] && [ "$fp" = "$OLD" ]; then n=$((n + 1)); else printf '%s\n' "$line" >>"$tmp"; fi
done <"$ak"
if [ "$n" -ne 1 ]; then echo "matched $n lines, expected 1: nothing changed" >&2; rm -f "$tmp"; exit 1; fi
chmod 600 "$tmp"
mv "$tmp" "$ak"
echo "removed 1 line"
EOF
```

#### Tern host key and host list

Do this if you use Tern.

- The Mac's Tern keeps one pin per VM in `~/Library/Application Support/Tern/known_hosts` (a line `<ipv4>:8376 SHA256:<fingerprint>`; Tern 0.7.0).
- It keeps its host list in `~/Library/Application Support/Tern/hosts` (`<user>@<ipv4>`; a VM whose Tern started before the drop-in can also have a `<user>@<endpoint id>` line).
- The new VM has a new Tern host key, so the old pin is stale. Delete that line from `known_hosts`, delete a stale `<user>@<endpoint id>` line from `hosts`, then run `tern remote setup <user>@<ipv4>` again.
- `tern remote trust HOST FINGERPRINT` pins by hand and `tern remote host-key --user` on the VM prints its fingerprint. Both are from `tern remote`'s usage text; they were not run here, and what Tern says about a stale pin was not captured.

#### The omp .env file and the gh login

Both were on the old disk; do them again (see [Personal setup](#personal-setup-hindsight-plugins-skills)).

### Kexec failed while the VM still runs Debian

Rerun `just vm-install <name>`.

### State store unreachable before a run starts

Plan, apply, `vm-install` and `vm-deploy` fail before they change anything. `vm-ip` says it could not read the VM list from the state (ignore any "no VM named" text from older versions). Retry when the store is back.

### State store dropped during an apply

This happens on a reboot or a network drop. OpenTofu cannot save the new state. It writes it, encrypted, to `errored.tfstate` in its working directory, `infra/proxmox/vms/.terragrunt-cache/<hash>/<hash>/` (find it with `find infra/proxmox/vms/.terragrunt-cache -name errored.tfstate`), and the lock object stays.

Do NOT rerun the apply (it plans the same VMs again) and do NOT delete `.terragrunt-cache`.

When the store is back:

1. Force-unlock ([Stale lock](#stale-lock)).
2. Copy `errored.tfstate` out (`cp -p`, keep mode 600).
3. Upload it as the state object ([Restore the state object](#restore-the-state-object)).
4. `just infra-plan` must show no changes for what was applied.

`tofu state push` does not work here: it refuses an encrypted file.

### Stale lock

A crashed run can leave the lock object `dotfiles-infra/proxmox-vms/terraform.tfstate.tflock`. Force-unlock only when no run is active (the id is in the lock error):

```bash
cd infra/proxmox/vms && SECRETSPEC_FILE=../../secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- terragrunt force-unlock <id>
```

### Back up the state object

Do this before applies that replace or destroy a VM; a timestamped name keeps the last good copy. Copy the object as is, to a private path outside the repo. Never `tofu state pull` into a file: that is decrypted plaintext.

```bash
SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- sh -c 'umask 077; aws --region us-east-1 --endpoint-url "$TF_STATE_S3_ENDPOINT" s3 cp "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate" "$HOME/infra-state-$(date +%Y%m%dT%H%M%S).backup"'
```

### Restore the state object

Use this when no run is active, after a lost or damaged object, or after an outage during an apply. Upload the encrypted file as is, then plan.

```bash
SECRETSPEC_FILE=infra/secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- sh -c 'aws --region us-east-1 --endpoint-url "$TF_STATE_S3_ENDPOINT" s3 cp <file> "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate"'
just infra-plan
```

`just infra-plan` must show no changes for what the file holds. What was applied after a backup shows as to-create: import it before any apply, then read what the plan still wants to change. This path was not exercised:

```bash
cd infra/proxmox/vms && SECRETSPEC_FILE=../../secretspec.toml SECRETSPEC_REASON="dotfiles infra" secretspec run -- terragrunt import 'proxmox_virtual_environment_vm.vm["<name>"]' <node>/<vmid>
# and per node: terragrunt import 'proxmox_download_file.debian["<node>"]' <node>/<datastore>:import/<file name>
```

The ids are as in the bpg/proxmox 0.112 docs. The passphrase must be the one the file was written with.

### The object no longer decrypts

This happens when the passphrase in OpenBao was lost or changed, or the object is damaged. Every command fails with a decrypt error, `import` included.

1. Move the object aside first (same `secretspec run -- sh -c '…'` form, with `s3 mv "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate" "s3://$TF_STATE_S3_BUCKET/dotfiles-infra/proxmox-vms/terraform.tfstate.unreadable"`).
2. Then restore a backup made with the right passphrase, or import.

The passphrase lives in OpenBao and in any offline copy you made ([Offline copies](#offline-copies)). Without one, losing it makes every backup unreadable too.

## Notes

- `docs/SETUP.md` is a stub. This README is the setup path.
- `just docs` / `just docs-serve` expect an mdbook tree that is not present.
- Formatter is **alejandra** (`just fmt`), not nixfmt.
- Lint baseline: [docs/EXEMPTIONS.md](docs/EXEMPTIONS.md).
