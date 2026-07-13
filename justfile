# Build the system config and switch to it when running `just` with no args
default: switch

hostname := `hostname | cut -d "." -f 1`

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

# Build the nix-darwin configuration and switch to it.
# darwin-rebuild is already installed system-wide, so activate directly in a
# single evaluation. The old form pre-built with `nix build` (eval+realize as
# your user) and then re-evaluated the whole flake via `--flake` under sudo
# (as root) — two full, cache-disjoint evals (~1-2 min each). This does one.
[macos]
switch target_host=hostname: _sudo
  @echo "switching to new config for {{target_host}}"
  sudo darwin-rebuild switch --flake ".#{{target_host}}"

# Update flake inputs to their latest revisions
update:
  # nix flake update --option access-tokens "github.com=$(gh auth token)"
  nix flake update

# Update system configuration (flake update + rebuild)
update-system target_host=hostname: update (switch target_host)

# Build and activate home configuration only.
# Convention: host name = primary username (e.g. host `le` → user `le`).
# If a future host needs a different username, override target_host with the
# username, or replace this recipe with one that reads system.primaryUser.
home target_host=hostname:
  @echo "Building home config for {{target_host}}..."
  nix build ".#darwinConfigurations.{{target_host}}.config.home-manager.users.{{target_host}}.home.activationPackage"
  @echo "Activating home configuration..."
  ./result/activate

# Upgrade Homebrew packages explicitly. `upgrade = false` in the homebrew config
# keeps `just switch` fast by not upgrading on every activation; run this when
# you actually want upgrades. Versions track the pinned taps, so run `just
# update` first to pull newer formula/cask definitions.
brew-upgrade:
  HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade

# Garbage collect old OS generations and remove stale packages from the nix store
gc:
  nix-collect-garbage -d

### Development and Validation
# Check flake syntax and build without switching
check:
  @echo "🔍 Checking flake configuration..."
  nix flake check --no-build

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

# Run all validation checks
validate: check fmt-check lint deadnix
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
