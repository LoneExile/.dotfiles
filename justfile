# Build the system config and switch to it when running `just` with no args
default: switch

hostname := `hostname | cut -d "." -f 1`
# Account running `just`: selects this Mac's Home Manager user, whatever the
# host is called. Home Manager refuses to activate for anyone else anyway.
user := `id -un`
# Home Manager's own profile for this user, chosen the way its activation script
# does (genProfilePath): $XDG_STATE_HOME/nix/profiles if that directory exists,
# else the global per-user profiles directory. Both `just home` and `just switch`
# link the new generation here; /etc/profiles/per-user (PATH) only follows
# `just switch`.
hm_profile := `d="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles"; [ -d "$d" ] || d="${NIX_STATE_DIR:-/nix/var/nix}/profiles/per-user/$(id -un)"; echo "$d/home-manager"`
dotfiles_secrets := hm_profile / "home-path/bin/dotfiles-secrets"
infra_dir := justfile_directory() / "infra"
infra_unit := infra_dir / "proxmox/vms"

### System Management
# Build the nix-darwin system configuration without switching to it
[macos]
build target_host=hostname flags="":
  @echo "Building nix-darwin config..."
  nix --extra-experimental-features 'nix-command flakes'  build ".#darwinConfigurations.{{target_host}}.system" {{flags}}

# Build the nix-darwin config with the --show-trace flag set
[macos]
trace target_host=hostname: (build target_host "--show-trace")

# Prompt for the sudo password up front, before the build runs
_sudo:
  @sudo -v

# Log in to the homelab OpenBao via Keycloak SSO and write ~/.vault-token.
# Required once per machine (and before each token expiry) for dotfiles-secrets
# to sync secrets like the SSH keys materialized on every switch.
# Uses the OIDC mount default role — `secretspec-human` is OcinCloud-only.
[macos]
openbao-login:
  BAO_ADDR=https://openbao.home.0dl.me bao login -method=oidc -path=oidc


# The three recipes below run the dotfiles-secrets wrapper of the active Home
# Manager generation (so they work right after `just home`), falling back to the
# one on PATH.
# Read-only: every secret's sync state against OpenBao, then the secretspec CLI contract check
[macos]
secretspec-status:
  #!/usr/bin/env bash
  set -euo pipefail
  ds="{{dotfiles_secrets}}"
  [[ -x $ds ]] || ds=$(command -v dotfiles-secrets) || { echo "error: dotfiles-secrets is not installed yet: run just home" >&2; exit 1; }
  "$ds" status
  SECRETSPEC_FILE="{{justfile_directory()}}/secretspec.toml" bash "{{justfile_directory()}}/home/secretspec/contract-check.sh"

# Review secrets against OpenBao and push or pull (needs a terminal; --push NAME pushes one, no prompts)
[macos]
secretspec-sync *ARGS:
  #!/usr/bin/env bash
  set -euo pipefail
  ds="{{dotfiles_secrets}}"
  [[ -x $ds ]] || ds=$(command -v dotfiles-secrets) || { echo "error: dotfiles-secrets is not installed yet: run just home" >&2; exit 1; }
  "$ds" sync {{ARGS}}

# Copy Tern's live settings.json (the preferences UI rewrites it in place) back
# into the repo, so the change reaches the other MacBook through git — commit
# it, pull there, run `just home`. See home.activation.ternSettings.
[macos]
tern-capture:
  #!/usr/bin/env bash
  set -euo pipefail
  dst="{{justfile_directory()}}/home/tern/settings.json"
  cp -f "$HOME/Library/Application Support/Tern/settings.json" "$dst"
  echo "captured Tern settings -> $dst"
  git -C "{{justfile_directory()}}" --no-pager diff --stat -- home/tern/settings.json || true

# Copy this Mac's omp plugin manifests (package.json, bun.lock, omp-plugins.lock.json from ~/.omp/plugins)
# into home/omp/plugins, for the agent VMs: the stale lock entries are dropped, and the capture is
# refused (nothing written) when a file holds a token, a URL, an absolute path or a local source.
# Review `git diff`, commit, then `just vm-deploy <name>`. See home/omp/plugins-capture.sh.
[macos]
omp-plugins-capture:
  #!/usr/bin/env bash
  set -euo pipefail
  bash "{{justfile_directory()}}/home/omp/plugins-capture.sh" "$HOME/.omp/plugins" "{{justfile_directory()}}/home/omp/plugins"
  git -C "{{justfile_directory()}}" --no-pager diff --stat -- home/omp/plugins || true

# Once, after every Mac runs this engine: OpenBao then refuses writes to the secrets without check-and-set
[macos]
secretspec-enforce-cas:
  #!/usr/bin/env bash
  set -euo pipefail
  ds="{{dotfiles_secrets}}"
  [[ -x $ds ]] || ds=$(command -v dotfiles-secrets) || { echo "error: dotfiles-secrets is not installed yet: run just home" >&2; exit 1; }
  "$ds" enforce-cas

# If ~/.config/omniwm/settings.toml is a regular file, Home Manager will not
# replace it. Review nvim -d / diff -u, then y to remove so the symlink can land.
_omniwm-adopt:
  @bash "{{justfile_directory()}}/home/omniwm/adopt.sh"

# Build the nix-darwin configuration and switch to it.
# darwin-rebuild is already installed system-wide, so activate directly in a
# single evaluation. The old form pre-built with `nix build` (eval+realize as
# your user) and then re-evaluated the whole flake via `--flake` under sudo
# (as root) — two full, cache-disjoint evals (~1-2 min each). This does one.
[macos]
switch target_host=hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  bash "{{justfile_directory()}}/home/omniwm/adopt.sh"
  sudo -v
  echo "switching to new config for {{target_host}}"
  sudo darwin-rebuild switch --flake ".#{{target_host}}"

# Update flake inputs to their latest revisions.
# Unauthenticated GitHub API is 60 req/hr and 403s; pass `gh auth token` when logged in.
update:
  #!/usr/bin/env bash
  set -euo pipefail
  if token=$(gh auth token 2>/dev/null); then
    nix flake update --option access-tokens "github.com=${token}"
  else
    nix flake update
  fi

# Update system configuration (flake update + rebuild)
update-system target_host=hostname: update (switch target_host)

# Build and activate home configuration only, for the user running `just`
# (Home Manager rejects activating another user's home). Override with
# `just user=<name> home`.
[macos]
home target_host=hostname: _omniwm-adopt
  @echo "Building home config for {{user}}@{{target_host}}..."
  nix build ".#darwinConfigurations.{{target_host}}.config.home-manager.users.{{user}}.home.activationPackage"
  @echo "Activating home configuration..."
  ./result/activate

# Upgrade Homebrew packages explicitly. `upgrade = false` in the homebrew config
# keeps `just switch` fast by not upgrading on every activation; run this when
# you actually want upgrades.
# Formulae come from the taps nix-homebrew rsyncs out of the flake inputs during
# `just switch` (mutableTaps) — never from `brew update`. Upgrading against taps
# older than flake.lock fails for formulae with moving download URLs (lightpanda's
# `nightly` asset: the pinned sha no longer matches the file). `just update`
# always rewrites the lock (homebrew-core/cask move constantly), so when the lock
# is newer than the active system, switch first. Symlink mtimes are compared
# because store paths are epoch-dated.
[macos]
brew-upgrade target_host=hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(stat -f %m flake.lock)" -gt "$(stat -f %m /run/current-system)" ]; then
    echo "flake.lock is newer than the active system: syncing Homebrew taps with 'just switch' first" >&2
    just switch "{{target_host}}"
  fi
  # Casks that remove a launchctl service (VS Code, Discord) call sudo from
  # Homebrew's Ruby, and sudo does not honour a ticket this shell obtained
  # (a prior `sudo -v` was tested and changes nothing), so a password prompt can
  # appear mid-run. Formula-only upgrades never need sudo.
  export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1
  if ! brew upgrade --yes; then
    echo "brew upgrade finished with failures; still outdated:" >&2
    brew outdated --verbose >&2
    exit 1
  fi

# Update everything: flake inputs, then the system (which syncs the taps), then
# Homebrew packages. `just update && just brew-upgrade` reaches the same state.
update-all target_host=hostname: (update-system target_host) (brew-upgrade target_host)

# Garbage collect old OS generations and remove stale packages from the nix store
gc:
  nix-collect-garbage -d

### Proxmox NixOS VMs
# Test the leak check, the vault map helpers, the VM identity files, the VM roles, the VM sync, the plugin capture and install scripts and the agent role's writable config copies (no network, no vault)
test-infra:
  @echo "🔎 Testing the infra leak check, vault map helpers, VM identity files, VM roles, VM sync, plugin scripts and writable config copies..."
  bash infra/leak-check_test.sh
  bash infra/vault-map_test.sh
  bash infra/vm-identity_test.sh
  bash infra/vm-role_test.sh
  bash infra/vm-flow_test.sh
  bash infra/vm-sync-remote_test.sh
  bash infra/vm-sync_test.sh
  bash infra/vm-hindsight-health_test.sh
  bash home/linux/writable-copy_test.sh
  bash home/linux/omp-plugins-install_test.sh
  bash home/omp/plugins-capture_test.sh

# Guard the roles: proxmox-guest stays clean (TCP 22 only, no user), proxmox-agent stays confined (evaluates the flake, no VM)
test-roles:
  @echo "🔒 Checking the roles..."
  bash infra/roles-check.sh

# Plan the Proxmox VMs, with secrets from OpenBao through secretspec
infra-plan *ARGS:
  cd "{{infra_unit}}" && SECRETSPEC_FILE="{{infra_dir}}/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" secretspec run -- terragrunt plan {{ARGS}}

# Apply the Proxmox VMs, with secrets from OpenBao through secretspec
infra-apply *ARGS:
  cd "{{infra_unit}}" && SECRETSPEC_FILE="{{infra_dir}}/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" secretspec run -- terragrunt apply {{ARGS}}

# Scan tracked files for the real server values held in the infra secrets
infra-leak-check:
  cd "{{justfile_directory()}}" && SECRETSPEC_FILE="{{infra_dir}}/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" secretspec run -- bash infra/leak-check.sh

# Install NixOS with an encrypted root on a fresh Debian VM from infra output (refuses if debian@ login fails)
vm-install name:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{infra_unit}}"
  SECRETSPEC_FILE="{{infra_dir}}/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" secretspec run -- bash "{{infra_dir}}/vm-install.sh" {{quote(name)}} "{{justfile_directory()}}"

# Unlock a VM that waits for its disk passphrase in the initrd (after vm-install, a reboot or a host restart)
vm-unlock name:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{infra_unit}}"
  SECRETSPEC_FILE="{{infra_dir}}/secretspec.toml" SECRETSPEC_REASON="dotfiles infra" secretspec run -- bash "{{infra_dir}}/vm-unlock.sh" {{quote(name)}}

# Deploy the NixOS configuration of the VM's role (clean: proxmox-guest, agent: proxmox-agent) to an installed VM
vm-deploy name:
  #!/usr/bin/env bash
  set -euo pipefail
  bash "{{infra_dir}}/vm-deploy.sh" {{quote(name)}} "{{justfile_directory()}}"

# Sync the Hindsight URL and key (this VM's entry in the vault map VM_HINDSIGHT) and the Mac's skills library to the agent user of a VM (role agent); vm-deploy runs it after an agent deploy
vm-sync name:
  #!/usr/bin/env bash
  set -euo pipefail
  bash "{{infra_dir}}/vm-sync.sh" {{quote(name)}} "{{justfile_directory()}}"

### Development and Validation
# Check flake syntax and build without switching
check:
  @echo "🔍 Checking flake configuration..."
  nix flake check --no-build
  @! git grep -nE '/Users/[A-Za-z0-9._-]+' || { echo "hardcoded /Users/<name> above: use \$HOME, ~ or config.home.homeDirectory"; exit 1; }

# Format all Nix files
fmt:
  @echo "🎨 Formatting Nix files..."
  alejandra **/*.nix

# Check formatting without making changes
fmt-check:
  @echo "🔍 Checking Nix file formatting..."
  alejandra --check **/*.nix

# Run linter on Nix files
lint:
  @echo "🔍 Linting Nix files..."
  statix check .

# Find dead code in Nix files
deadnix:
  @echo "🔍 Checking for dead code..."
  deadnix .

# Test the secret-sync engine against a throwaway `bao server -dev` (no network)
test-secrets:
  @echo "🔐 Testing the secret-sync engine..."
  bash home/secretspec/materialize_test.sh

# Run all validation checks
validate: check fmt-check lint deadnix test-secrets test-infra test-roles
  @echo "✅ All validation checks completed!"

### Documentation
# Build documentation
docs:
  @echo "📚 Building documentation..."
  @if [ -d "docs" ]; then \
    cd docs && mdbook build; \
    echo "✅ Documentation built in docs/book/"; \
  else \
    echo "❌ No docs directory found"; \
  fi

# Serve documentation locally
docs-serve:
  @echo "📚 Serving documentation locally..."
  @if [ -d "docs" ]; then \
    cd docs && mdbook serve; \
  else \
    echo "❌ No docs directory found"; \
  fi

### Development Environment
# Enter development shell
dev:
  @echo "🚀 Entering development environment..."
  nix develop

# Enter minimal development shell
dev-minimal:
  @echo "🚀 Entering minimal development environment..."
  nix develop .#minimal

# Enter documentation development shell
dev-docs:
  @echo "📚 Entering documentation development environment..."
  nix develop .#docs

### Templates
# List available templates
templates:
  @echo "📋 Available templates:"
  @echo "  default     - Basic modular Nix configuration"
  @echo "  minimal     - Minimal Nix configuration"
  @echo "  development - Development-focused configuration"

# Initialize a new configuration from template
init template="default" path=".":
  @echo "🎯 Initializing {{template}} template in {{path}}..."
  nix flake init --template .#{{template}} {{path}}

### Utilities
# Show system information
info:
  @echo "🖥️  System Information:"
  @echo "Hostname: $(hostname)"
  @echo "System: $(uname -m)-darwin"
  @echo "Nix version: $(nix --version)"
  @echo "Darwin generation: $(darwin-rebuild --list-generations | tail -1)"

# Show flake inputs and their versions
inputs:
  @echo "📦 Flake inputs:"
  nix flake metadata --json | jq -r '.locks.nodes | to_entries[] | select(.value.locked) | "\(.key): \(.value.locked.rev // .value.locked.ref // "unknown")"'

# Clean up build artifacts and temporary files
clean:
  @echo "🧹 Cleaning up..."
  rm -rf result result-*
  @echo "✅ Cleanup complete!"
