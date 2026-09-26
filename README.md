# ~/.dotfiles

Personal macOS config: **nix-darwin** (system) + **Home Manager** (user), driven by this flake.

Live host is **`lex`** (hostname = username). `le` is the same shape, kept as a second darwinConfiguration.

## Daily commands

| Command | What it does |
|---|---|
| `just switch` | Full nix-darwin rebuild + activate. Needs sudo. Same OmniWM settings.toml preflight as `just home`. |
| `just home` | Home Manager only. No sudo. Use for zsh / `home.file` / secretspec materialization. If `~/.config/omniwm/settings.toml` is a regular file, reviews the diff then y/N before replacing it with the repo symlink. |
| `just openbao-login` | Keycloak SSO → `~/.vault-token`. Required before activation can pull secrets. |
| `just secretspec-sync` | Review local vs OpenBao secret files, then y/N to push/pull. |
| `just update-all` | `just update` → `just switch` → `just brew-upgrade`. |
| `just brew-upgrade` | `brew upgrade` on demand. `just switch` does **not** upgrade Homebrew. Runs `just switch` first when `flake.lock` is newer than the active system (taps sync on switch). Casks that remove launchctl services (VS Code, Discord) prompt for sudo mid-run; a shell `sudo -v` can't pre-authorise Homebrew's own sudo. |
| `just update` | `nix flake update` (lockfile only). |
| `just gc` | `nix-collect-garbage -d`. |
| `just --list` | Everything else (`check`, `fmt`, `lint`, `build`, `trace`). |


`just` with no args runs `switch`.

After `just home` / `just switch`, a **new shell** (or `exec zsh`) is required for zshrc / keymap changes. Running shells keep the old init.

## Layout

```
flake.nix                 darwinConfigurations.lex / .le
justfile                  the commands above
lib/builders.nix          mkDarwin: HM, nix-homebrew, overlays
hosts/<name>/             hostname, primaryUser, host-only tweaks
hosts/common/             shared darwin defaults (nix, TouchID sudo, keyboard)
profiles/development.nix  CLI / k8s / fonts
profiles/personal.nix     Homebrew casks + personal packages
home/default.nix          Home Manager: packages, programs.*, activation
home/zsh/                 zshrc + aliases / options / keybindings
secretspec.toml           secret *names* only (no values)
home/secretspec/          secretspec provider aliases → OpenBao
home/omniwm/              OmniWM settings.toml (out-of-store symlink) + adopt.sh
home/herdr/               herdr config.toml + herdr-plus quick-actions
```

Profiles are boolean toggles on `lib.mkDarwin` in `flake.nix`, not files under `hosts/common/profiles/`.

## Secrets

Live path is **secretspec → homelab OpenBao**, not SOPS.

- Manifest: `secretspec.toml` (`[profiles.default]`). Names and dest paths only.
- Values: `secret/secretspec/dotfiles/default/<NAME>` on `https://openbao.home.0dl.me`.
- Activation: `home.activation.secretspecSecrets` runs `home/secretspec/materialize.sh apply` on every `just home` / `just switch`. 3-way via `~/.local/state/dotfiles/secretspec/<NAME>.sha256` (on-disk bytes, not raw `secretspec get`): vault-newer → pull; local-newer → leave dest and hint `just secretspec-sync`; both changed → fail; equal (including first apply with no last-sync) → record hash. Missing secret → activation **fails**. `secretspec` 0.20 `get` always appends a newline, even when redirected; apply/sync strip that one byte for keep secrets so a push is not seen as vault-newer on the next run.
- Atuin sync login: `home.activation.atuinLogin` runs `home/secretspec/atuin-login.sh` after materialize and Home Manager's `linkGeneration` (it needs `config.toml`; any earlier, atuin writes its default config and targets Atuin's hosted server). `atuin status` OK → nothing (password not read). Otherwise `atuin login -u loneexile --key ""` with `ATUIN_PASSWORD` from OpenBao (argv only, never on disk); `--key ""` reuses the synced key file without rewriting it, so `ATUIN_KEY` stays in sync. Login/network failures print a `!!!!` banner and activation continues; `ATUIN_PASSWORD` missing while logged out fails activation.
- Review / push: `just secretspec-sync` (TTY). `nvim -d` with swap/shada/undo disabled; if nvim is missing, `diff -u` for `OMP_ENV` / `NPMRC` and `bytes differ` for SSH keys + Atuin key / AI token.
- Login: `just openbao-login` (recipe name is `openbao-login`, not `secretspec-login`).
- Binary: `~/.cargo/bin/secretspec` (install script, not the nixpkgs package).

SOPS is leftover, not live: no `secrets/secrets.yaml`, no `sops.secrets.*` in any host/profile. What remains is the `sops-nix` input, `mkDarwin`'s unused darwin module, `.sops.yaml`, and `secrets/note.md`. Ignore those; do not put tokens in `programs.atuin.settings` or git.

Prefer `just secretspec-sync`. Manual set (keeps trailing newlines):

```bash
value=$(cat /path/to/file; printf x)
value=${value%x}
secretspec set NAME --reason "why" -- "$value"
```



## New machine

1. Install Nix (Determinate), Xcode CLT, clone this repo to `~/.dotfiles`.
2. `curl -sSL https://install.secretspec.dev | sh`
3. `just openbao-login`
4. First activation (nix-darwin not on PATH yet):

   ```bash
   nix run nix-darwin -- switch --flake .#lex
   ```

   After that: `just switch`.
5. `mise install` (language runtimes are mise, not nix packages).

Activation will refuse if OpenBao is unreachable or a declared secret is missing.

Atuin sync logs itself in during that activation (`atuinLogin`); no manual `atuin login`.

## New host

1. `cp -r hosts/_template hosts/<hostname>` and fill hostname / username / home.
2. Register in `flake.nix`:

   ```nix
   <hostname> = lib.mkDarwin {
     hostname = "<hostname>";
     username = "<username>";   # just home assumes this equals hostname
     system = "aarch64-darwin";
     profiles = { development = true; personal = true; };
   };
   ```

3. `just switch` (or `just switch <hostname>`).

See `hosts/lex/default.nix` for the live example.

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

## Notes

- `docs/SETUP.md` is a stub. This README is the setup path.
- `just docs` / `just docs-serve` expect an mdbook tree that is not present.
- Formatter is **alejandra** (`just fmt`), not nixfmt.
- Lint baseline: [docs/EXEMPTIONS.md](docs/EXEMPTIONS.md).
