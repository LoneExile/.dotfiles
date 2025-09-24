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
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **Clone this repository**:
   ```bash
   git clone https://github.com/yourusername/nix-config.git ~/.dotfiles
   cd ~/.dotfiles
   ```

3. **Review and customize** the configuration:
   ```bash
   # Copy the example host configuration
   cp hosts/_template/default.nix hosts/$(hostname)/default.nix
   
   # Edit the new host configuration
   $EDITOR hosts/$(hostname)/default.nix
   
   # Update flake.nix to include your host
   # Add your hostname to darwinConfigurations
   ```

4. **Build and activate** the configuration:
   ```bash
   # First time setup (install nix-darwin)
   nix run nix-darwin -- switch --flake .#$(hostname)
   
   # Subsequent updates
   darwin-rebuild switch --flake .#$(hostname)
   
   # Or use the convenient just command
   just switch
   ```

### Quick Configuration Examples

#### Minimal Setup
```nix
# hosts/your-hostname/default.nix
{
  modules = {
    darwin.system.enable = true;
    home.shell.zsh.enable = true;
  };
  
  profiles = {
    minimal = true;
  };
}
```

#### Development Environment
```nix
# hosts/your-hostname/default.nix
{
  modules = {
    darwin = {
      system.enable = true;
      homebrew.enable = true;
    };
    home = {
      shell.zsh.enable = true;
      development = {
        git.enable = true;
        editors.enable = true;
        languages.enable = true;
      };
    };
  };
  
  profiles = {
    development = true;
    personal = true;
  };
}
```

#### Work Environment
```nix
# hosts/your-hostname/default.nix
{
  modules = {
    darwin = {
      system.enable = true;
      homebrew.enable = true;
      security.enable = true;
    };
    home = {
      shell.zsh.enable = true;
      development.git.enable = true;
      desktop.productivity.enable = true;
    };
  };
  
  profiles = {
    work = true;
    development = true;
  };
}
```

## 📁 Structure

This configuration is organized into the following directories:

```
├── README.md                     # This file
├── flake.nix                     # Main flake configuration
├── flake.lock                    # Locked dependencies
├── lib/                          # Reusable library functions
│   ├── default.nix              # Main library exports
│   ├── builders.nix             # System builders (mkDarwin, etc.)
│   └── utils.nix                # Utility functions
├── modules/                      # Feature modules organized by category
│   ├── darwin/                  # macOS-specific modules
│   │   ├── system.nix          # Core system settings
│   │   ├── homebrew.nix        # Homebrew configuration
│   │   ├── security.nix        # Security settings
│   │   └── defaults.nix        # macOS preferences
│   ├── home/                   # Home Manager modules
│   │   ├── shell/              # Shell configuration
│   │   ├── development/        # Development tools
│   │   ├── desktop/            # Desktop applications
│   │   └── security/           # Security tools
│   └── shared/                 # Cross-platform modules
├── profiles/                   # Predefined configuration profiles
│   ├── minimal.nix            # Essential tools only
│   ├── development.nix        # Full development environment
│   ├── work.nix              # Work-specific configuration
│   └── personal.nix          # Personal use optimization
├── hosts/                     # Host-specific configurations
│   ├── common/               # Shared host configuration
│   └── your-hostname/        # Host-specific overrides
├── config/                   # Configuration files
├── docs/                     # Documentation
├── scripts/                  # Utility scripts
└── secrets/                  # SOPS encrypted secrets
```

## 🎯 Profiles

Choose from predefined profiles that suit your use case:

| Profile | Description | Includes |
|---------|-------------|----------|
| **minimal** | Essential tools only | Basic shell, core utilities |
| **development** | Full development environment | Git, editors, languages, containers |
| **work** | Work-specific configuration | Productivity apps, security tools |
| **personal** | Personal use optimization | Media tools, personal apps |

Profiles can be combined - for example, you can enable both `development` and `work` profiles.

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
- **[Module Documentation](docs/MODULES.md)** - Complete module reference and examples
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