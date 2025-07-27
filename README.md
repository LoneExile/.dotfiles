# macOS Nix Configuration

This repository contains a complete macOS system configuration using [Nix](https://nixos.org/) and [nix-darwin](https://github.com/LnL7/nix-darwin). It provides a declarative, reproducible way to manage your macOS system, applications, and development environment.

## 🚀 What This Configuration Does

This setup provides:
- **System Management**: Complete macOS system configuration through nix-darwin
- **Package Management**: Mix of Nix packages and Homebrew integration
- **User Environment**: Personal configurations managed by Home Manager
- **Development Tools**: Pre-configured development environment with Neovim, CLI tools, and more
- **Secrets Management**: Secure handling of sensitive data using SOPS
- **Window Management**: AeroSpace window manager for improved productivity

## 📁 Repository Structure

### Root Files

#### `flake.nix`
The **heart** of this configuration. This is the main entry point that:
- Defines all input sources (nixpkgs, nix-darwin, home-manager, etc.)
- Configures the system for Apple Silicon Macs (`aarch64-darwin`)
- Sets up the "le" host configuration (you'll want to change this to your hostname)
- Integrates Homebrew support through nix-homebrew
- Manages secrets with SOPS

**Key sections:**
```nix
darwinConfigurations = {
  # This defines your system configuration - change "le" to your hostname
  le = libx.mkDarwin { hostname = "le"; };
};
```

#### `flake.lock`
Auto-generated file that locks all dependencies to specific versions. This ensures reproducible builds across different machines and times. **Don't edit manually** - use `just update` to update dependencies.

#### `justfile`
A task runner configuration (like Makefile but simpler). Provides convenient commands:
- `just` or `just switch` - Build and apply system configuration
- `just build` - Build configuration without switching
- `just trace` - Build with detailed error messages
- `just update` - Update all flake inputs
- `just gc` - Clean up old generations and free disk space

### 📚 `lib/` Directory

Contains helper functions and utilities used throughout the configuration.

#### `lib/default.nix`
Main library file that exports helper functions used by the configuration system.

#### `lib/helpers.nix`
**Core helper functions:**
- `mkDarwin`: Creates a complete macOS system configuration
  - Sets up nix-darwin with the specified hostname
  - Configures Home Manager integration
  - Sets up SOPS for secrets management
  - Applies common macOS settings
  - **Default username**: "le" (you'll want to change this)

### 🏠 `hosts/` Directory

Contains system-level configurations organized by platform and specific machines.

#### `hosts/common/`
Shared configurations used across all macOS systems.

##### `hosts/common/common-packages.nix`
**System-wide packages** installed for all users:
- **Development tools**: git, curl, wget, jq, etc.
- **CLI utilities**: Modern replacements like `eza` (better ls), `bat` (better cat)
- **System tools**: htop, tree, unzip, etc.
- **Fonts**: Nerd Fonts for terminal icons and symbols

##### `hosts/common/darwin-common.nix`
**Core macOS system configuration:**
- **System preferences**: Keyboard settings, security options
- **Homebrew integration**: Manages GUI applications
- **User account setup**: Creates and configures the primary user
- **Nix settings**: Enables flakes, configures garbage collection
- **TouchID**: Enables TouchID for sudo authentication

##### `hosts/common/darwin-common-dock.nix`
**Default dock configuration:**
- Removes all default applications from dock
- Sets dock position and behavior
- Configures dock appearance (size, autohide, etc.)

#### `hosts/darwin/le/`
**Machine-specific configuration** for the host named "le". You'll want to rename this directory to match your hostname.

##### `hosts/darwin/le/default.nix`
**Host-specific settings:**
- System hostname configuration
- Machine-specific package installations
- Imports custom dock configuration
- Can override any common settings for this specific machine

##### `hosts/darwin/le/custom-dock.nix`
**Personal dock applications:**
Currently configured with:
- Google Chrome
- Ghostty (terminal emulator)
- You can customize this list for your preferred applications

### 🏡 `home/` Directory

Contains user-specific configurations managed by Home Manager.

#### `home/le.nix`
**Complete user environment configuration:**
- **Git configuration**: Username, email, aliases, and settings
- **Shell setup**: Zsh with custom configuration
- **SSH configuration**: Key management and host settings
- **Program configurations**: Settings for various CLI tools
- **Personal preferences**: Terminal colors, editor settings, etc.

**Current personal info (you'll want to change these):**
```nix
programs.git = {
  userName = "Apinant U-suwantim";
  userEmail = "Hello@Apinant.dev";
};
```

#### `home/aerospace/`
Configuration for [AeroSpace](https://github.com/nikitabobko/AeroSpace) - a tiling window manager for macOS.

##### `home/aerospace/aerospace.toml`
**Window management configuration:**
- Keyboard shortcuts for window manipulation
- Workspace management
- Tiling behavior and rules
- Integration with macOS spaces

#### `home/nvim/`
Neovim configuration files for a fully-featured development environment.

##### `home/nvim/options.lua`
**Neovim basic settings:**
- Line numbers, indentation, search behavior
- Editor appearance and behavior
- File handling and backup settings

##### `home/nvim/keymap.lua`
**Custom key bindings:**
- Productivity shortcuts
- Navigation improvements
- Custom command mappings

##### `home/nvim/plugins/telescope.lua`
**Telescope plugin configuration:**
- Fuzzy finder for files, grep, buffers
- Search and navigation enhancements
- Integration with other development tools

#### `home/starship/`
Configuration for [Starship](https://starship.rs/) - a customizable shell prompt.

##### `home/starship/starship.toml`
**Shell prompt customization:**
- Git status display
- Directory information
- Command execution time
- Custom prompt symbols and colors

### 📦 `data/` Directory

Contains additional configuration files and data.

#### `data/mac-dot-zshrc`
**macOS-specific Zsh configuration:**
- Shell aliases and functions
- Environment variables
- macOS-specific shell integrations
- Development environment setup

### 🔐 `secrets/` Directory

Manages encrypted secrets using SOPS (Secrets OPerationS).

#### `secrets/note.md`
**Comprehensive SOPS documentation** explaining:
- How encryption works in this setup
- How to generate and manage age keys
- How to add, edit, and use secrets
- Security best practices
- Integration with nix-darwin

**Key concepts:**
- Secrets are encrypted with your public key
- Only you can decrypt them with your private key
- Safe to store encrypted secrets in git
- Integrates seamlessly with system configuration

## 🛠 Getting Started

### Prerequisites
1. **macOS** (Apple Silicon or Intel)
2. **Nix package manager** installed
3. **Git** for cloning this repository

### Installation Steps

1. **Clone this repository:**
   ```bash
   git clone <your-repo-url>
   cd nix-config
   ```

2. **Customize for your system:**
   - Change hostname from "le" to your machine name in `flake.nix`
   - Rename `hosts/darwin/le/` to `hosts/darwin/your-hostname/`
   - Update personal information in `home/le.nix` (rename file too)
   - Update git configuration with your name and email

3. **Set up secrets (optional):**
   ```bash
   # Generate age key for encryption
   nix shell nixpkgs#age -c age-keygen > ~/.config/sops/age/keys.txt
   
   # Update .sops.yaml with your public key
   # Edit secrets as needed
   nix run nixpkgs#sops -- secrets/secrets.yaml
   ```

4. **Build and apply configuration:**
   ```bash
   # Install just task runner
   nix-env -iA nixpkgs.just
   
   # Build and switch to new configuration
   just switch
   ```

### Daily Usage

```bash
# Apply configuration changes
just switch

# Update all dependencies
just update

# Clean up old generations
just gc

# Build without switching (for testing)
just build

# Build with detailed error output
just trace
```

## 🎨 Customization Guide

### Adding New Packages

**System packages** (available to all users):
Add to `hosts/common/common-packages.nix`

**User packages** (Home Manager):
Add to `home/your-username.nix`

**GUI applications** (Homebrew):
Add to `hosts/common/darwin-common.nix` in the homebrew section

### Customizing Applications

**Dock applications:**
Edit `hosts/darwin/your-hostname/custom-dock.nix`

**Shell configuration:**
Edit `data/mac-dot-zshrc` or shell settings in `home/your-username.nix`

**Development environment:**
Edit configurations in `home/nvim/` for Neovim settings

### System Settings

**macOS system preferences:**
Edit `hosts/common/darwin-common.nix`

**Machine-specific settings:**
Edit `hosts/darwin/your-hostname/default.nix`

## 🔍 Understanding the Architecture

This configuration uses a **layered approach**:

1. **System layer** (`hosts/`): OS-level configuration, packages, services
2. **User layer** (`home/`): Personal environment, dotfiles, user applications
3. **Common layer** (`hosts/common/`): Shared settings across all machines
4. **Machine layer** (`hosts/darwin/hostname/`): Host-specific overrides

**Data flow:**
```
flake.nix → lib/helpers.nix → hosts/common/* + hosts/darwin/hostname/* + home/*
```

## 🔄 Maintenance

### Updating the System
```bash
# Update all flake inputs to latest versions
just update

# Rebuild system with updates
just switch
```

### Cleaning Up
```bash
# Remove old system generations and free space
just gc
```

### Troubleshooting
```bash
# Build with detailed error messages
just trace

# Check what would be built without building
nix flake check
```

## 📝 Notes for Beginners

### What is Nix?
- **Nix** is a package manager that ensures reproducible builds
- **nix-darwin** extends Nix to manage macOS system configuration
- **Home Manager** manages user-specific configurations
- **Flakes** provide a modern way to define and share Nix configurations

### Key Benefits
1. **Reproducible**: Same configuration works across different machines
2. **Declarative**: Describe what you want, not how to get it
3. **Rollback**: Easy to revert to previous configurations
4. **Isolated**: Changes don't affect other parts of the system
5. **Shareable**: Configuration can be version controlled and shared

### Important Files to Understand
1. **flake.nix** - Main configuration entry point
2. **hosts/common/darwin-common.nix** - System-wide macOS settings
3. **home/your-username.nix** - Your personal environment
4. **justfile** - Convenient commands for managing the system

Start by exploring these files and making small changes to understand how everything connects together!

