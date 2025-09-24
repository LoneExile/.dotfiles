#!/bin/bash
# Migration helper script for Homebrew to Nix configuration
# Usage: ./scripts/migrate-from-homebrew.sh [hostname]

set -e

MIGRATION_DIR="$HOME/migration-backup"
CONFIG_DIR="$(pwd)"
HOSTNAME="${1:-$(hostname)}"

echo "=== Modular Nix Configuration Migration ==="
echo "Host: $HOSTNAME"
echo "Migration backup: $MIGRATION_DIR"
echo "Config directory: $CONFIG_DIR"
echo

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
        ["python3"]="python3"
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
        ["fzf"]="fzf"
        ["gh"]="gh"
        ["awscli"]="awscli2"
        ["azure-cli"]="azure-cli"
        ["gcloud"]="google-cloud-sdk"
        ["mysql"]="mysql80"
        ["postgresql"]="postgresql"
        ["redis"]="redis"
        ["mongodb"]="mongodb"
        ["sqlite"]="sqlite"
        ["nginx"]="nginx"
        ["apache2"]="apache-httpd"
        ["yarn"]="yarn"
        ["npm"]="nodejs"
        ["pip"]="python3Packages.pip"
        ["pipenv"]="pipenv"
        ["poetry"]="poetry"
        ["rbenv"]="rbenv"
        ["nvm"]="nvm"
        ["pyenv"]="pyenv"
        ["tfenv"]="tfenv"
        ["java"]="openjdk"
        ["maven"]="maven"
        ["gradle"]="gradle"
        ["sbt"]="sbt"
        ["leiningen"]="leiningen"
        ["clojure"]="clojure"
        ["scala"]="scala"
        ["kotlin"]="kotlin"
        ["swift"]="swift"
        ["rust"]="rustc"
        ["cargo"]="cargo"
        ["gcc"]="gcc"
        ["clang"]="clang"
        ["make"]="gnumake"
        ["cmake"]="cmake"
        ["ninja"]="ninja"
        ["autoconf"]="autoconf"
        ["automake"]="automake"
        ["libtool"]="libtool"
        ["pkg-config"]="pkg-config"
        ["openssl"]="openssl"
        ["zlib"]="zlib"
        ["libxml2"]="libxml2"
        ["libxslt"]="libxslt"
        ["imagemagick"]="imagemagick"
        ["ffmpeg"]="ffmpeg"
        ["youtube-dl"]="youtube-dl"
        ["yt-dlp"]="yt-dlp"
        ["pandoc"]="pandoc"
        ["graphviz"]="graphviz"
        ["gnupg"]="gnupg"
        ["pass"]="pass"
        ["ssh-copy-id"]="openssh"
        ["rsync"]="rsync"
        ["rclone"]="rclone"
        ["unzip"]="unzip"
        ["p7zip"]="p7zip"
        ["tar"]="gnutar"
        ["gzip"]="gzip"
        ["bzip2"]="bzip2"
        ["xz"]="xz"
    )
    
    # Extract brew packages from Brewfile
    if grep -q '^brew ' "$brewfile"; then
        grep '^brew ' "$brewfile" | sed 's/brew "\([^"]*\)".*/\1/' > "$MIGRATION_DIR/brew-packages.txt"
    else
        touch "$MIGRATION_DIR/brew-packages.txt"
    fi
    
    # Convert to Nix packages
    > "$output_file"
    echo "# Nix packages converted from Homebrew" >> "$output_file"
    echo "# Add these to environment.systemPackages in your configuration" >> "$output_file"
    echo "" >> "$output_file"
    
    while IFS= read -r package; do
        if [[ -n "${package_map[$package]}" ]]; then
            echo "  ${package_map[$package]}" >> "$output_file"
        else
            echo "  # TODO: Find Nix equivalent for: $package" >> "$output_file"
        fi
    done < "$MIGRATION_DIR/brew-packages.txt"
    
    echo "Package conversion complete. Check $output_file"
}

# Function to extract Homebrew casks
extract_casks() {
    local brewfile="$MIGRATION_DIR/Brewfile"
    local output_file="$MIGRATION_DIR/homebrew-casks.txt"
    
    if [ ! -f "$brewfile" ]; then
        return 1
    fi
    
    echo "Extracting Homebrew casks..."
    
    > "$output_file"
    echo "# Homebrew casks to add to your configuration" >> "$output_file"
    echo "# Add these to homebrew.casks in your configuration" >> "$output_file"
    echo "" >> "$output_file"
    
    if grep -q '^cask ' "$brewfile"; then
        grep '^cask ' "$brewfile" | sed 's/cask "\([^"]*\)".*/  "\1"/' >> "$output_file"
    fi
    
    echo "Cask extraction complete. Check $output_file"
}

# Function to migrate configuration files
migrate_configs() {
    local host_config="hosts/$HOSTNAME/default.nix"
    
    echo "Migrating configuration files..."
    
    # Check if host configuration exists
    if [ ! -f "$host_config" ]; then
        echo "Host configuration not found: $host_config"
        echo "Please copy an example configuration first:"
        echo "  cp -r hosts/examples/development-workstation hosts/$HOSTNAME"
        return 1
    fi
    
    # Create backup of original config
    cp "$host_config" "$host_config.backup"
    
    # Update hostname and username in configuration
    sed -i.tmp "s/HOSTNAME/$HOSTNAME/g" "$host_config"
    sed -i.tmp "s/USERNAME/$USER/g" "$host_config"
    rm "$host_config.tmp"
    
    # Copy important config files to the new structure
    mkdir -p "configs/$HOSTNAME"
    
    if [ -f "$MIGRATION_DIR/configs/.gitconfig" ]; then
        cp "$MIGRATION_DIR/configs/.gitconfig" "configs/$HOSTNAME/"
        echo "Migrated Git configuration"
    fi
    
    if [ -d "$MIGRATION_DIR/configs/.ssh" ]; then
        cp -r "$MIGRATION_DIR/configs/.ssh" "configs/$HOSTNAME/"
        echo "Migrated SSH configuration"
    fi
    
    if [ -d "$MIGRATION_DIR/configs/.gnupg" ]; then
        cp -r "$MIGRATION_DIR/configs/.gnupg" "configs/$HOSTNAME/"
        echo "Migrated GPG configuration"
    fi
    
    echo "Configuration migration complete"
}

# Function to create migration summary
create_summary() {
    local summary_file="$MIGRATION_DIR/migration-summary.md"
    
    echo "Creating migration summary..."
    
    cat > "$summary_file" << EOF
# Migration Summary for $HOSTNAME

Generated on: $(date)

## Files Created/Modified

- Host configuration: hosts/$HOSTNAME/default.nix
- Nix packages list: $MIGRATION_DIR/nix-packages.txt
- Homebrew casks list: $MIGRATION_DIR/homebrew-casks.txt
- Configuration backup: configs/$HOSTNAME/

## Next Steps

1. Review and edit hosts/$HOSTNAME/default.nix
2. Add packages from nix-packages.txt to environment.systemPackages
3. Add casks from homebrew-casks.txt to homebrew.casks
4. Test the configuration: nix build .#darwinConfigurations.$HOSTNAME.system
5. Apply the configuration: darwin-rebuild switch --flake .#$HOSTNAME

## Manual Review Required

- Check for packages marked with "TODO" in nix-packages.txt
- Verify all necessary applications are included
- Review system preferences and defaults
- Test critical workflows after migration

## Backup Locations

- Original system backup: Time Machine
- Migration files: $MIGRATION_DIR
- Original host config: hosts/$HOSTNAME/default.nix.backup
EOF

    echo "Migration summary created: $summary_file"
}

# Main migration function
main() {
    # Check if backup exists
    if [ ! -d "$MIGRATION_DIR" ]; then
        echo "Migration backup not found at $MIGRATION_DIR"
        echo "Please run the assessment first:"
        echo "  mkdir -p $MIGRATION_DIR"
        echo "  brew bundle dump --file=$MIGRATION_DIR/Brewfile"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "flake.nix" ]; then
        echo "Not in a Nix flake directory. Please run from the root of your nix-config."
        exit 1
    fi
    
    # Convert packages
    convert_brew_to_nix
    
    # Extract casks
    extract_casks
    
    # Migrate configurations
    migrate_configs
    
    # Create summary
    create_summary
    
    echo
    echo "=== Migration preparation complete! ==="
    echo
    echo "Next steps:"
    echo "1. Review hosts/$HOSTNAME/default.nix"
    echo "2. Add packages from $MIGRATION_DIR/nix-packages.txt"
    echo "3. Add casks from $MIGRATION_DIR/homebrew-casks.txt"
    echo "4. Test with: nix build .#darwinConfigurations.$HOSTNAME.system"
    echo "5. Apply with: darwin-rebuild switch --flake .#$HOSTNAME"
    echo
    echo "See $MIGRATION_DIR/migration-summary.md for detailed instructions."
}

# Run main function
main "$@"