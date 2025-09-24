#!/bin/bash
# Migration validation script
# Usage: ./scripts/validate-migration.sh [hostname]

set -e

HOSTNAME="${1:-$(hostname)}"
MIGRATION_DIR="$HOME/migration-backup"
CONFIG_DIR="$(pwd)"

echo "=== Migration Validation Report ==="
echo "Host: $HOSTNAME"
echo "Date: $(date)"
echo "Config Directory: $CONFIG_DIR"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "pass")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "fail")
            echo -e "${RED}✗${NC} $message"
            ;;
        "warn")
            echo -e "${YELLOW}?${NC} $message"
            ;;
    esac
}

# Function to validate configuration syntax
validate_config_syntax() {
    echo "=== Configuration Syntax Validation ==="
    
    local host_config="hosts/$HOSTNAME/default.nix"
    
    if [ -f "$host_config" ]; then
        print_status "pass" "Host configuration exists: $host_config"
        
        # Check Nix syntax
        if nix-instantiate --parse "$host_config" >/dev/null 2>&1; then
            print_status "pass" "Configuration syntax is valid"
        else
            print_status "fail" "Configuration has syntax errors"
            echo "Run: nix-instantiate --parse $host_config"
            return 1
        fi
    else
        print_status "fail" "Host configuration missing: $host_config"
        return 1
    fi
}

# Function to validate configuration build
validate_config_build() {
    echo "=== Configuration Build Validation ==="
    
    # Try to build the configuration
    if nix build ".#darwinConfigurations.$HOSTNAME.system" --dry-run 2>/dev/null; then
        print_status "pass" "Configuration builds successfully (dry-run)"
    else
        print_status "fail" "Configuration build failed"
        echo "Run: nix build \".#darwinConfigurations.$HOSTNAME.system\" --show-trace"
        return 1
    fi
}

# Function to check package availability
validate_packages() {
    echo "=== Package Availability Validation ==="
    
    local packages_file="$MIGRATION_DIR/nix-packages.txt"
    
    if [ -f "$packages_file" ]; then
        local total_packages=0
        local available_packages=0
        local missing_packages=0
        
        while IFS= read -r line; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
                continue
            fi
            
            # Extract package name (remove leading whitespace)
            local package=$(echo "$line" | sed 's/^[[:space:]]*//')
            
            if [ -n "$package" ]; then
                total_packages=$((total_packages + 1))
                
                # Check if package is available
                if nix-env -qa | grep -q "^$package"; then
                    available_packages=$((available_packages + 1))
                    print_status "pass" "$package is available"
                else
                    missing_packages=$((missing_packages + 1))
                    print_status "warn" "$package not found - may need alternative"
                fi
            fi
        done < "$packages_file"
        
        echo
        echo "Package Summary:"
        echo "  Total packages: $total_packages"
        echo "  Available: $available_packages"
        echo "  Missing/Need alternatives: $missing_packages"
        
        if [ $missing_packages -gt 0 ]; then
            echo
            echo "For missing packages, try:"
            echo "  nix search nixpkgs package-name"
        fi
    else
        print_status "warn" "Package list not found: $packages_file"
    fi
}

# Function to validate Homebrew casks
validate_homebrew_casks() {
    echo "=== Homebrew Casks Validation ==="
    
    local casks_file="$MIGRATION_DIR/homebrew-casks.txt"
    local host_config="hosts/$HOSTNAME/default.nix"
    
    if [ -f "$casks_file" ] && [ -f "$host_config" ]; then
        local total_casks=0
        local found_casks=0
        local missing_casks=0
        
        while IFS= read -r line; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
                continue
            fi
            
            # Extract cask name (remove quotes and whitespace)
            local cask=$(echo "$line" | sed 's/^[[:space:]]*"//' | sed 's/"[[:space:]]*$//')
            
            if [ -n "$cask" ]; then
                total_casks=$((total_casks + 1))
                
                # Check if cask is in the configuration
                if grep -q "\"$cask\"" "$host_config"; then
                    found_casks=$((found_casks + 1))
                    print_status "pass" "$cask found in configuration"
                else
                    missing_casks=$((missing_casks + 1))
                    print_status "warn" "$cask not found in configuration"
                fi
            fi
        done < "$casks_file"
        
        echo
        echo "Homebrew Casks Summary:"
        echo "  Total casks: $total_casks"
        echo "  Found in config: $found_casks"
        echo "  Missing from config: $missing_casks"
    else
        print_status "warn" "Casks file or host config not found"
    fi
}

# Function to validate system requirements
validate_system_requirements() {
    echo "=== System Requirements Validation ==="
    
    # Check Nix installation
    if command -v nix >/dev/null 2>&1; then
        print_status "pass" "Nix is installed ($(nix --version))"
    else
        print_status "fail" "Nix is not installed"
        return 1
    fi
    
    # Check nix-darwin
    if command -v darwin-rebuild >/dev/null 2>&1; then
        print_status "pass" "nix-darwin is available"
    else
        print_status "fail" "nix-darwin is not installed"
        return 1
    fi
    
    # Check flake support
    if nix flake --help >/dev/null 2>&1; then
        print_status "pass" "Nix flakes are supported"
    else
        print_status "fail" "Nix flakes are not enabled"
        return 1
    fi
    
    # Check disk space
    local available_space=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "${available_space%.*}" -gt 5 ]; then
        print_status "pass" "Sufficient disk space available (${available_space}G)"
    else
        print_status "warn" "Low disk space (${available_space}G) - may cause issues"
    fi
}

# Function to validate configuration completeness
validate_config_completeness() {
    echo "=== Configuration Completeness Validation ==="
    
    local host_config="hosts/$HOSTNAME/default.nix"
    
    if [ ! -f "$host_config" ]; then
        print_status "fail" "Host configuration not found"
        return 1
    fi
    
    # Check for placeholder values
    if grep -q "HOSTNAME\|USERNAME" "$host_config"; then
        print_status "fail" "Configuration contains placeholder values (HOSTNAME/USERNAME)"
    else
        print_status "pass" "No placeholder values found"
    fi
    
    # Check for required sections
    local required_sections=("networking.hostName" "users.users" "system.primaryUser")
    
    for section in "${required_sections[@]}"; do
        if grep -q "$section" "$host_config"; then
            print_status "pass" "Required section found: $section"
        else
            print_status "warn" "Required section missing: $section"
        fi
    done
    
    # Check for profile import
    if grep -q "profiles.*\.nix" "$host_config"; then
        print_status "pass" "Profile import found"
    else
        print_status "warn" "No profile import found"
    fi
}

# Function to validate backup integrity
validate_backup_integrity() {
    echo "=== Backup Integrity Validation ==="
    
    if [ -d "$MIGRATION_DIR" ]; then
        print_status "pass" "Migration backup directory exists"
        
        # Check for key backup files
        local backup_files=("Brewfile" "brew-formulae.txt" "brew-casks.txt")
        
        for file in "${backup_files[@]}"; do
            if [ -f "$MIGRATION_DIR/$file" ]; then
                print_status "pass" "Backup file exists: $file"
            else
                print_status "warn" "Backup file missing: $file"
            fi
        done
        
        # Check backup size
        local backup_size=$(du -sh "$MIGRATION_DIR" | cut -f1)
        print_status "pass" "Backup size: $backup_size"
    else
        print_status "warn" "Migration backup directory not found"
    fi
    
    # Check for Time Machine backup
    if tmutil latestbackup >/dev/null 2>&1; then
        local latest_backup=$(tmutil latestbackup)
        print_status "pass" "Time Machine backup available: $(basename "$latest_backup")"
    else
        print_status "warn" "No Time Machine backup found"
    fi
}

# Function to generate validation report
generate_report() {
    local report_file="$MIGRATION_DIR/validation-report.txt"
    
    echo "=== Generating Validation Report ==="
    
    {
        echo "Migration Validation Report"
        echo "=========================="
        echo "Host: $HOSTNAME"
        echo "Date: $(date)"
        echo "Validator: $(whoami)"
        echo
        echo "System Information:"
        echo "  macOS Version: $(sw_vers -productVersion)"
        echo "  Nix Version: $(nix --version 2>/dev/null || echo 'Not installed')"
        echo "  Darwin Rebuild: $(command -v darwin-rebuild >/dev/null && echo 'Available' || echo 'Not available')"
        echo
        echo "Configuration Status:"
        echo "  Host Config: $([ -f "hosts/$HOSTNAME/default.nix" ] && echo 'Exists' || echo 'Missing')"
        echo "  Syntax Valid: $(nix-instantiate --parse "hosts/$HOSTNAME/default.nix" >/dev/null 2>&1 && echo 'Yes' || echo 'No')"
        echo "  Build Test: $(nix build ".#darwinConfigurations.$HOSTNAME.system" --dry-run >/dev/null 2>&1 && echo 'Pass' || echo 'Fail')"
        echo
        echo "Migration Files:"
        echo "  Backup Directory: $([ -d "$MIGRATION_DIR" ] && echo 'Exists' || echo 'Missing')"
        echo "  Package List: $([ -f "$MIGRATION_DIR/nix-packages.txt" ] && echo 'Exists' || echo 'Missing')"
        echo "  Casks List: $([ -f "$MIGRATION_DIR/homebrew-casks.txt" ] && echo 'Exists' || echo 'Missing')"
        echo
        echo "Recommendations:"
        if ! nix-instantiate --parse "hosts/$HOSTNAME/default.nix" >/dev/null 2>&1; then
            echo "  - Fix configuration syntax errors"
        fi
        if ! nix build ".#darwinConfigurations.$HOSTNAME.system" --dry-run >/dev/null 2>&1; then
            echo "  - Resolve configuration build issues"
        fi
        if grep -q "HOSTNAME\|USERNAME" "hosts/$HOSTNAME/default.nix" 2>/dev/null; then
            echo "  - Replace placeholder values in configuration"
        fi
        echo "  - Review and test critical applications after migration"
        echo "  - Keep backup until migration is fully verified"
    } > "$report_file"
    
    print_status "pass" "Validation report generated: $report_file"
}

# Main validation function
main() {
    # Check if we're in the right directory
    if [ ! -f "flake.nix" ]; then
        print_status "fail" "Not in a Nix flake directory"
        echo "Please run from the root of your nix-config."
        exit 1
    fi
    
    local exit_code=0
    
    # Run all validations
    validate_system_requirements || exit_code=1
    echo
    validate_backup_integrity
    echo
    validate_config_syntax || exit_code=1
    echo
    validate_config_completeness
    echo
    validate_config_build || exit_code=1
    echo
    validate_packages
    echo
    validate_homebrew_casks
    echo
    
    # Generate report
    generate_report
    
    echo
    echo "=== Validation Summary ==="
    if [ $exit_code -eq 0 ]; then
        print_status "pass" "All critical validations passed"
        echo "You can proceed with: darwin-rebuild switch --flake .#$HOSTNAME"
    else
        print_status "fail" "Some critical validations failed"
        echo "Please address the issues before proceeding with migration."
    fi
    
    echo
    echo "Detailed report available at: $MIGRATION_DIR/validation-report.txt"
    
    exit $exit_code
}

# Run main function
main "$@"