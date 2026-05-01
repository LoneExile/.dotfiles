# Modular Nix Configuration

A modular, well-documented Nix configuration for macOS that follows community best practices. This configuration provides a flexible, maintainable system for managing your development environment using Nix Darwin and Home Manager.

## ✨ Features

- 🧩 **Modular Architecture** - Organized into reusable, configurable modules
- 📚 **Well Documented** - Comprehensive documentation and examples
- 🎯 **Profile System** - Predefined configurations for different use cases
- 🔒 **Secrets Management** - SOPS integration for secure configuration
- 🛠️ **Development Ready** - Full development environment with modern tools
- 🔄 **Easy Updates** - Simple commands for system updates and maintenance
- 🧪 **Testing Support** - Built-in validation and testing tools

## 🚀 Quick Start

### Prerequisites

Before installing, ensure you have:

- **macOS** (Darwin) - This configuration is designed for macOS systems
- **Nix Package Manager** with flakes enabled
- **Git** for cloning the repository
- **Command Line Tools** for Xcode (install with `xcode-select --install`)

### Installation

1. **Install Nix** (if not already installed):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --prefer-upstream-nix

   ## and then check system update
   ```

2. **Clone this repository**:
   ```bash
   git clone https://github.com/loneexile/.dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ```

3. **Add your host**:
   ```bash
   # Copy the host template
   cp -r hosts/_template hosts/$(hostname)

   # Replace HOSTNAME / USERNAME / "Full Name" with your values
   $EDITOR hosts/$(hostname)/default.nix
   ```

   Then register the host in `flake.nix` under `darwinConfigurations`:
   ```nix
   darwinConfigurations = {
     "${YOUR_HOSTNAME}" = lib.mkDarwin {
       hostname = "${YOUR_HOSTNAME}";
       username = "${YOUR_USERNAME}";
       system   = "aarch64-darwin";   # or "x86_64-darwin"
       profiles = { development = true; personal = true; };
     };
   };
   ```

4. **Build and activate** the configuration:
   ```bash
   # First time setup (install nix-darwin)
   nix run nix-darwin -- switch --flake .#$(hostname)
   
   # Subsequent updates
   darwin-rebuild switch --flake .#$(hostname)
   
   # Or use the convenient just command
   just switch

   mise install
   ```

### Configuration Pattern

Each host file (`hosts/<name>/default.nix`) contains the actual customization
(packages, Homebrew brews/casks, macOS defaults, activation scripts). Profiles
are passed as boolean toggles to `lib.mkDarwin` in `flake.nix`. See
`hosts/le/default.nix` for a working example with Homebrew, fonts, and macOS
preferences.

## 📁 Structure

This configuration is organized into the following directories:

```
├── README.md          # This file
├── flake.nix          # Main flake configuration; darwinConfigurations live here
├── flake.lock         # Locked dependencies
├── justfile           # Common commands (just build, just switch, just home, ...)
├── lib/               # Reusable library functions
│   ├── default.nix    # Main library exports (mkDarwin, utils, ...)
│   ├── builders.nix   # System builders
│   └── utils.nix      # Utility functions
├── profiles/          # Profile toggles consumed by lib.mkDarwin
│   ├── development.nix
│   └── personal.nix
├── hosts/             # Host-specific configurations
│   ├── _template/     # Starter template for new hosts
│   ├── common/        # Shared base config imported by every host
│   └── le/            # Personal MacBook host
├── home/              # Home Manager config (default.nix used by every user)
├── config/            # Auxiliary configuration files
├── docs/              # Documentation
├── scripts/           # Utility scripts
├── secrets/           # SOPS-encrypted secrets
└── templates/         # Independent flake templates for new projects
```

## 🎯 Profiles

Profile toggles enable curated bundles of settings via `lib.mkDarwin`.

| Profile | Description |
|---------|-------------|
| **development** | Full development environment |
| **personal** | Personal use optimization |

Profiles can be combined — see `flake.nix` for how `darwinConfigurations.le`
enables `development` and `personal` together. Add new profiles as `.nix`
files under `profiles/` to expose new toggles.

## 🔧 Common Tasks

### Update System
```bash
# Update flake inputs and rebuild
just update

# Or manually:
nix flake update
darwin-rebuild switch --flake .
```

### Add New Software
```bash
# Add to a module or host configuration
# Then rebuild
darwin-rebuild switch --flake .
```

### Validate Configuration
```bash
# Check configuration syntax and formatting
just check

# Or use individual commands:
nix flake check
nixfmt **/*.nix
statix check .
```

### Development Environment
```bash
# Enter development shell
nix develop

# Or use specific shells:
nix develop .#minimal    # Minimal tools
nix develop .#docs      # Documentation tools
```

## 📚 Documentation

- **[Setup Instructions](docs/SETUP.md)** - Detailed installation and configuration guide
- **[Host Template README](hosts/_template/README.md)** - Adding a new MacBook
- **[Lint Exemptions](docs/EXEMPTIONS.md)** - Documented baseline lint warnings
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Contributing](docs/CONTRIBUTING.md)** - Development workflows and guidelines

## 🛠️ Available Commands

This configuration includes a `justfile` with common commands:

```bash
just --list              # Show all available commands
just check               # Validate configuration
just build               # Build configuration
just update              # Update and rebuild system
just clean               # Clean build artifacts
just docs                # Build documentation
just format              # Format Nix files
```

## 🔒 Secrets Management

This configuration uses SOPS for managing secrets:

1. **Setup SOPS** (first time):
   ```bash
   # Generate age key
   age-keygen -o ~/.config/sops/age/keys.txt
   
   # Add public key to .sops.yaml
   ```

2. **Edit secrets**:
   ```bash
   sops secrets/secrets.yaml
   ```

3. **Use in configuration**:
   ```nix
   sops.secrets.example = {
     sopsFile = ../secrets/secrets.yaml;
   };
   ```

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for:

- Development setup
- Code style guidelines
- Testing procedures
- Pull request process

## 📄 License

This configuration is provided as-is for educational and personal use. Feel free to fork and adapt for your own needs.

## 🆘 Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check the [docs/](docs/) directory for detailed guides

---

**Happy Nix-ing!** 🎉
