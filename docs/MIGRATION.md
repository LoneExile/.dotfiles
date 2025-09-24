# Migration Guide

This guide helps you migrate from existing configurations to the modular Nix configuration system. Whether you're coming from a Homebrew-only setup, another Nix configuration, or a manual system setup, this guide provides step-by-step instructions and automated tools to make the transition smooth.

## Overview

The migration process involves several key steps:

1. **Assessment**: Analyze your current configuration and installed software
2. **Backup**: Create backups of your current system and configurations
3. **Preparation**: Set up the new Nix configuration structure
4. **Migration**: Transfer settings, applications, and data to the new system
5. **Validation**: Verify that everything works correctly after migration
6. **Cleanup**: Remove old configuration files and unused software

## Migration Scenarios

This guide covers the following migration scenarios:

- **From Homebrew-only setup**: Migrating from a pure Homebrew installation
- **From existing Nix configuration**: Migrating from nix-darwin or home-manager
- **From manual setup**: Migrating from manually installed applications and tools
- **From other macOS configuration managers**: Migrating from Ansible, Chef, or similar tools

## Prerequisites

Before starting the migration:

- macOS 10.15 (Catalina) or later
- Administrator access to your system
- At least 10GB of free disk space
- Stable internet connection for downloading packages
- Time Machine backup or equivalent system backup

## Step 1: Assessment and Inventory

### Current System Analysis

Before migrating, you need to understand what's currently installed on your system.

#### Homebrew Inventory

If you're using Homebrew, create an inventory of your current installations:

```bash
# Create a backup directory
mkdir -p ~/migration-backup

# Export Homebrew packages
brew bundle dump --file=~/migration-backup/Brewfile

# List all installed formulae
brew list --formula > ~/migration-backup/brew-formulae.txt

# List all installed casks
brew list --cask > ~/migration-backup/brew-casks.txt

# List tapped repositories
brew tap > ~/migration-backup/brew-taps.txt

# Export Homebrew services
brew services list > ~/migration-backup/brew-services.txt
```

#### System Applications Inventory

Create an inventory of applications installed outside of Homebrew:

```bash
# List applications in /Applications
ls -la /Applications > ~/migration-backup/applications.txt

# List applications in ~/Applications
ls -la ~/Applications > ~/migration-backup/user-applications.txt 2>/dev/null || echo "No user applications directory"

# List Mac App Store applications (requires mas)
if command -v mas >/dev/null 2>&1; then
    mas list > ~/migration-backup/mas-apps.txt
else
    echo "mas not installed - Mac App Store apps will need manual inventory"
fi
```

#### Configuration Files Inventory

Backup important configuration files:

```bash
# Create config backup directory
mkdir -p ~/migration-backup/configs

# Common configuration directories
for dir in .config .ssh .gnupg .aws .docker; do
    if [ -d "$HOME/$dir" ]; then
        cp -r "$HOME/$dir" ~/migration-backup/configs/
        echo "Backed up $dir"
    fi
done

# Shell configuration files
for file in .bashrc .bash_profile .zshrc .zsh_profile .profile; do
    if [ -f "$HOME/$file" ]; then
        cp "$HOME/$file" ~/migration-backup/configs/
        echo "Backed up $file"
    fi
done

# Git configuration
if [ -f "$HOME/.gitconfig" ]; then
    cp "$HOME/.gitconfig" ~/migration-backup/configs/
fi
```## St
ep 2: System Backup

### Time Machine Backup

Create a complete system backup before proceeding:

```bash
# Start Time Machine backup (if configured)
tmutil startbackup

# Check backup status
tmutil status

# List available backups
tmutil listbackups
```

### Manual Backup of Critical Data

Even with Time Machine, create manual backups of critical data:

```bash
# Create comprehensive backup directory
mkdir -p ~/migration-backup/critical-data

# Backup development projects
if [ -d "$HOME/Development" ]; then
    rsync -av "$HOME/Development/" ~/migration-backup/critical-data/Development/
fi

# Backup Documents
rsync -av "$HOME/Documents/" ~/migration-backup/critical-data/Documents/

# Backup Desktop files
rsync -av "$HOME/Desktop/" ~/migration-backup/critical-data/Desktop/

# Backup any custom scripts or tools
if [ -d "$HOME/bin" ]; then
    rsync -av "$HOME/bin/" ~/migration-backup/critical-data/bin/
fi

if [ -d "$HOME/.local/bin" ]; then
    rsync -av "$HOME/.local/bin/" ~/migration-backup/critical-data/local-bin/
fi
```

### Database Backups

If you have local databases, back them up:

```bash
# PostgreSQL backup (if running)
if command -v pg_dumpall >/dev/null 2>&1; then
    pg_dumpall > ~/migration-backup/postgresql-backup.sql
fi

# MySQL backup (if running)
if command -v mysqldump >/dev/null 2>&1; then
    mysqldump --all-databases > ~/migration-backup/mysql-backup.sql
fi

# MongoDB backup (if running)
if command -v mongodump >/dev/null 2>&1; then
    mongodump --out ~/migration-backup/mongodb-backup
fi
```#
# Step 3: Preparation

### Install Nix

If Nix isn't already installed, install it using the Determinate Nix Installer:

```bash
# Install Nix using the Determinate installer (recommended)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Source the Nix environment
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Verify installation
nix --version
```

### Clone the Modular Configuration

Clone or download the modular Nix configuration:

```bash
# Clone the repository (replace with actual repository URL)
git clone https://github.com/your-org/modular-nix-config.git ~/nix-config

# Navigate to the configuration directory
cd ~/nix-config

# Review the available examples
ls hosts/examples/
```

### Choose Your Configuration Profile

Based on your assessment, choose the most appropriate example configuration:

- **Development Workstation**: For software developers and engineers
- **Work Laptop**: For corporate/business environments
- **Personal MacBook**: For personal daily use and hobby development
- **Minimal Server**: For headless servers or minimal setups
- **Multi-User Workstation**: For shared development environments

```bash
# Copy your chosen example to create your host configuration
cp -r hosts/examples/development-workstation hosts/$(hostname)

# Or use a custom hostname
cp -r hosts/examples/development-workstation hosts/my-macbook
```## Step 4: M
igration Scripts and Tools

### Automated Migration Script

Create an automated migration script to help with the process:

```bash
#!/bin/bash
# Migration helper script: scripts/migrate-from-homebrew.sh

set -e

MIGRATION_DIR="$HOME/migration-backup"
CONFIG_DIR="$(pwd)"
HOSTNAME="${1:-$(hostname)}"

echo "Starting migration for host: $HOSTNAME"

# Function to convert Homebrew formulae to Nix packages
convert_brew_to_nix() {
    local brewfile="$MIGRATION_DIR/Brewfile"
    local output_file="$MIGRATION_DIR/nix-packages.txt"
    
    if [ ! -f "$brewfile" ]; then
        echo "Brewfile not found. Run assessment first."
        return 1
    fi
    
    echo "Converting Homebrew packages to Nix equivalents..."
    
    # Common Homebrew to Nix package mappings
    declare -A package_map=(
        ["git"]="git"
        ["node"]="nodejs"
        ["python"]="python3"
        ["go"]="go"
        ["rust"]="rustc"
        ["docker"]="docker"
        ["kubectl"]="kubectl"
        ["terraform"]="terraform"
        ["ansible"]="ansible"
        ["vim"]="vim"
        ["neovim"]="neovim"
        ["tmux"]="tmux"
        ["htop"]="htop"
        ["jq"]="jq"
        ["curl"]="curl"
        ["wget"]="wget"
        ["tree"]="tree"
        ["ripgrep"]="ripgrep"
        ["fd"]="fd"
        ["bat"]="bat"
        ["exa"]="exa"
    )
    
    # Extract brew packages from Brewfile
    grep '^brew ' "$brewfile" | sed 's/brew "\([^"]*\)".*/\1/' > "$MIGRATION_DIR/brew-packages.txt"
    
    # Convert to Nix packages
    > "$output_file"
    while IFS= read -r package; do
        if [[ -n "${package_map[$package]}" ]]; then
            echo "${package_map[$package]}" >> "$output_file"
        else
            echo "# TODO: Find Nix equivalent for: $package" >> "$output_file"
        fi
    done < "$MIGRATION_DIR/brew-packages.txt"
    
    echo "Package conversion complete. Check $output_file"
}

# Function to migrate configuration files
migrate_configs() {
    local host_config="hosts/$HOSTNAME/default.nix"
    
    echo "Migrating configuration files..."
    
    # Update hostname in configuration
    sed -i.bak "s/HOSTNAME/$HOSTNAME/g" "$host_config"
    sed -i.bak "s/USERNAME/$USER/g" "$host_config"
    
    # Copy important config files to the new structure
    mkdir -p "configs/$HOSTNAME"
    
    if [ -f "$MIGRATION_DIR/configs/.gitconfig" ]; then
        cp "$MIGRATION_DIR/configs/.gitconfig" "configs/$HOSTNAME/"
    fi
    
    if [ -d "$MIGRATION_DIR/configs/.ssh" ]; then
        cp -r "$MIGRATION_DIR/configs/.ssh" "configs/$HOSTNAME/"
    fi
}

# Main migration function
main() {
    echo "=== Modular Nix Configuration Migration ==="
    echo "Host: $HOSTNAME"
    echo "Migration backup: $MIGRATION_DIR"
    echo "Config directory: $CONFIG_DIR"
    echo
    
    # Check if backup exists
    if [ ! -d "$MIGRATION_DIR" ]; then
        echo "Migration backup not found. Please run assessment first."
        exit 1
    fi
    
    # Convert packages
    convert_brew_to_nix
    
    # Migrate configurations
    migrate_configs
    
    echo
    echo "Migration preparation complete!"
    echo "Next steps:"
    echo "1. Review and edit hosts/$HOSTNAME/default.nix"
    echo "2. Add packages from $MIGRATION_DIR/nix-packages.txt"
    echo "3. Test the configuration with: nix build .#darwinConfigurations.$HOSTNAME.system"
    echo "4. Apply with: darwin-rebuild switch --flake .#$HOSTNAME"
}

# Run main function
main "$@"
```

Save this script and make it executable:

```bash
# Create the script
cat > scripts/migrate-from-homebrew.sh << 'EOF'
# [Script content from above]
EOF

# Make it executable
chmod +x scripts/migrate-from-homebrew.sh
```##
# Migration Validation Script

Create a validation script to verify the migration:

```bash
#!/bin/bash
# Migration validation script: scripts/validate-migration.sh

set -e

HOSTNAME="${1:-$(hostname)}"
MIGRATION_DIR="$HOME/migration-backup"

echo "Validating migration for host: $HOSTNAME"

# Function to check if a package is available
check_package() {
    local package="$1"
    if nix-env -qa | grep -q "^$package"; then
        echo "✓ $package is available in Nix"
        return 0
    else
        echo "✗ $package not found in Nix"
        return 1
    fi
}

# Function to validate configuration
validate_config() {
    echo "=== Configuration Validation ==="
    
    # Check if host configuration exists
    if [ -f "hosts/$HOSTNAME/default.nix" ]; then
        echo "✓ Host configuration exists"
    else
        echo "✗ Host configuration missing"
        return 1
    fi
    
    # Try to build the configuration
    echo "Testing configuration build..."
    if nix build ".#darwinConfigurations.$HOSTNAME.system" --dry-run; then
        echo "✓ Configuration builds successfully"
    else
        echo "✗ Configuration build failed"
        return 1
    fi
}

# Function to check application availability
validate_applications() {
    echo "=== Application Validation ==="
    
    if [ -f "$MIGRATION_DIR/brew-casks.txt" ]; then
        echo "Checking Homebrew casks migration..."
        while IFS= read -r cask; do
            # Check if cask is in the new configuration
            if grep -q "$cask" "hosts/$HOSTNAME/default.nix"; then
                echo "✓ $cask found in new configuration"
            else
                echo "? $cask not found - may need manual addition"
            fi
        done < "$MIGRATION_DIR/brew-casks.txt"
    fi
}

# Function to validate services
validate_services() {
    echo "=== Services Validation ==="
    
    if [ -f "$MIGRATION_DIR/brew-services.txt" ]; then
        echo "Checking services migration..."
        # This is a placeholder - actual service validation would be more complex
        echo "Manual review required for services migration"
    fi
}

# Main validation function
main() {
    echo "=== Migration Validation Report ==="
    echo "Host: $HOSTNAME"
    echo "Date: $(date)"
    echo
    
    validate_config
    echo
    validate_applications
    echo
    validate_services
    
    echo
    echo "Validation complete!"
    echo "Review any items marked with ✗ or ? before proceeding."
}

# Run main function
main "$@"
```

Save and make executable:

```bash
# Create the validation script
cat > scripts/validate-migration.sh << 'EOF'
# [Script content from above]
EOF

# Make it executable
chmod +x scripts/validate-migration.sh
```#
# Step 5: Migration Process

### From Homebrew-Only Setup

#### 1. Run the Assessment
```bash
# Create inventory of current system
mkdir -p ~/migration-backup
brew bundle dump --file=~/migration-backup/Brewfile
brew list --formula > ~/migration-backup/brew-formulae.txt
brew list --cask > ~/migration-backup/brew-casks.txt
```

#### 2. Prepare Nix Configuration
```bash
# Navigate to your nix configuration
cd ~/nix-config

# Run the migration helper
./scripts/migrate-from-homebrew.sh $(hostname)
```

#### 3. Customize Your Configuration
Edit your host configuration file:

```bash
# Edit the host configuration
vim hosts/$(hostname)/default.nix
```

Key areas to customize:
- **Hostname and username**: Update placeholder values
- **Package selection**: Add packages from the generated list
- **Homebrew casks**: Add GUI applications you need
- **System preferences**: Adjust macOS defaults to your liking

#### 4. Test the Configuration
```bash
# Test build without applying
nix build ".#darwinConfigurations.$(hostname).system"

# Run validation
./scripts/validate-migration.sh $(hostname)
```

#### 5. Apply the Configuration
```bash
# Apply the new configuration
darwin-rebuild switch --flake ".#$(hostname)"
```

#### 6. Verify Migration
```bash
# Check that applications are available
which git node python3

# Verify Homebrew casks are installed
ls /Applications/

# Test key applications
code --version  # VS Code
docker --version  # Docker
```

### From Existing Nix Configuration

#### 1. Analyze Current Configuration
```bash
# Backup current configuration
cp -r ~/.config/nixpkgs ~/migration-backup/nixpkgs-old
cp -r ~/.nixpkgs ~/migration-backup/nixpkgs-old 2>/dev/null || true

# If using nix-darwin
cp -r ~/.nixpkgs/darwin-configuration.nix ~/migration-backup/ 2>/dev/null || true
```

#### 2. Extract Package Lists
```bash
# Extract packages from existing configuration
grep -r "environment.systemPackages" ~/.config/nixpkgs/ > ~/migration-backup/old-packages.txt
grep -r "homebrew.casks" ~/.config/nixpkgs/ > ~/migration-backup/old-casks.txt
```

#### 3. Map to New Structure
```bash
# Create new host configuration based on existing setup
cp -r hosts/examples/development-workstation hosts/$(hostname)

# Manually transfer packages and settings from old configuration
# This requires reviewing the old configuration and mapping to new structure
```

#### 4. Migrate Custom Modules
```bash
# Copy custom modules if any
mkdir -p modules/custom
cp ~/.config/nixpkgs/modules/* modules/custom/ 2>/dev/null || true
```## Step 6: 
Troubleshooting Common Issues

### Build Failures

#### Syntax Errors
```bash
# Check Nix syntax
nix-instantiate --parse hosts/$(hostname)/default.nix

# Use nix repl to debug
nix repl
:l <nixpkgs>
:l ./hosts/$(hostname)/default.nix
```

#### Missing Packages
```bash
# Search for package alternatives
nix search nixpkgs package-name

# Check if package exists in different attribute
nix-env -qaP | grep package-name
```

#### Homebrew Integration Issues
```bash
# Ensure nix-homebrew is properly configured
nix build .#darwinConfigurations.$(hostname).system --show-trace

# Check Homebrew tap configuration
brew tap
```

### Application Issues

#### GUI Applications Not Appearing
```bash
# Rebuild launch services database
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Check if applications are in the right location
ls -la /Applications/
```

#### Command Line Tools Missing
```bash
# Check if tools are in PATH
echo $PATH

# Source Nix environment
source /etc/zshrc

# Check Nix profile
nix-env -q
```

### Permission Issues
```bash
# Fix Nix store permissions
sudo chown -R root:nixbld /nix

# Fix user permissions
sudo chown -R $USER:staff ~/nix-config
```

## Step 7: Cleanup

### Remove Old Homebrew (Optional)

⚠️ **Warning**: Only do this after verifying everything works correctly!

```bash
# Uninstall Homebrew completely
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"

# Remove Homebrew directories
sudo rm -rf /opt/homebrew
sudo rm -rf /usr/local/Homebrew
```

### Clean Up Old Configuration Files

```bash
# Remove old Nix configurations (after backing up)
rm -rf ~/.config/nixpkgs
rm -rf ~/.nixpkgs

# Clean up shell configuration files
# Remove Homebrew-related lines from ~/.zshrc or ~/.bash_profile
```

### Remove Migration Backup (After Verification)

```bash
# Only after everything is working correctly
rm -rf ~/migration-backup
```

## Post-Migration Tasks

### Update Documentation
- Document any custom configurations or workarounds
- Update team documentation if this is a shared setup
- Create notes for future migrations

### Set Up Automation
```bash
# Set up automatic updates (optional)
echo "0 9 * * 1 cd ~/nix-config && nix flake update && darwin-rebuild switch --flake ." | crontab -
```

### Monitor System Health
```bash
# Run diagnostics periodically
./scripts/diagnose-config.sh $(hostname)

# Check for issues
./scripts/validate-config.sh $(hostname)
```## 
Specific Migration Scenarios

### Scenario 1: Developer with Homebrew + Manual Installs

**Current Setup**: Homebrew for CLI tools, manual app installations, custom dotfiles

**Migration Steps**:
1. Export Homebrew packages: `brew bundle dump`
2. Inventory manual installations in `/Applications`
3. Backup dotfiles and configurations
4. Choose development workstation example
5. Map Homebrew packages to Nix equivalents
6. Add manual applications to Homebrew casks in Nix config
7. Integrate dotfiles into the new configuration structure

### Scenario 2: Corporate User with Security Requirements

**Current Setup**: Corporate-managed applications, VPN clients, security tools

**Migration Steps**:
1. Use work laptop example as base
2. Identify corporate-required applications
3. Ensure security compliance (encryption, VPN, etc.)
4. Test in isolated environment first
5. Coordinate with IT department for approval
6. Migrate gradually, keeping old setup as backup

### Scenario 3: Multi-User Development Machine

**Current Setup**: Shared Mac with multiple developer accounts

**Migration Steps**:
1. Use multi-user workstation example
2. Create separate user configurations
3. Set up shared development tools
4. Configure user isolation and permissions
5. Test with each user account
6. Migrate one user at a time

### Scenario 4: Minimal Server/CI Runner

**Current Setup**: Headless Mac mini used for CI/CD

**Migration Steps**:
1. Use minimal server example
2. Identify essential tools only
3. Remove all GUI applications
4. Configure for automation and remote access
5. Test CI/CD pipelines thoroughly
6. Set up monitoring and alerting

## Migration Checklist

### Pre-Migration
- [ ] Create Time Machine backup
- [ ] Export Homebrew packages (`brew bundle dump`)
- [ ] Inventory installed applications
- [ ] Backup configuration files
- [ ] Document current system setup
- [ ] Test Nix installation

### During Migration
- [ ] Choose appropriate example configuration
- [ ] Customize hostname and username
- [ ] Map packages from old to new system
- [ ] Configure system preferences
- [ ] Test configuration build
- [ ] Run validation scripts

### Post-Migration
- [ ] Verify all applications work
- [ ] Test development workflows
- [ ] Check system preferences
- [ ] Validate security settings
- [ ] Update documentation
- [ ] Clean up old configurations (optional)

## Getting Help

### Common Resources
- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [nix-darwin Documentation](https://github.com/LnL7/nix-darwin)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)

### Community Support
- [NixOS Discourse](https://discourse.nixos.org/)
- [Nix Community on GitHub](https://github.com/nix-community)
- [r/NixOS on Reddit](https://www.reddit.com/r/NixOS/)

### Project-Specific Help
- Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
- Review [Module Documentation](MODULES.md)
- Open an issue in the project repository

## Contributing Migration Improvements

If you encounter issues or develop better migration strategies:

1. Document the problem and solution
2. Update this migration guide
3. Contribute scripts or tools that help others
4. Share your experience with the community

Your contributions help make the migration process smoother for everyone!