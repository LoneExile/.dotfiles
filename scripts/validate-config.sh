#!/usr/bin/env bash

# Configuration validation script
# This script validates the Nix configuration before building

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VALIDATION_REPORT="/tmp/nix-config-validation-report.txt"

# Default values
HOSTNAME=""
SYSTEM=""
VERBOSE=false
CHECK_ONLY=false
GENERATE_REPORT=true

# Help function
show_help() {
    cat << EOF
Configuration Validation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -H, --hostname HOSTNAME Specify hostname to validate (default: auto-detect)
    -s, --system SYSTEM     Specify system type (default: auto-detect)
    -v, --verbose           Enable verbose output
    -c, --check-only        Only check validation, don't generate reports
    -r, --report PATH       Path for validation report (default: $VALIDATION_REPORT)
    --no-report             Don't generate validation report

EXAMPLES:
    $0                      # Validate current system
    $0 -H myhost -s aarch64-darwin  # Validate specific host
    $0 -v --check-only      # Verbose check without report generation

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Auto-detect system information
detect_system() {
    if [[ -z "$SYSTEM" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if [[ "$(uname -m)" == "arm64" ]]; then
                SYSTEM="aarch64-darwin"
            else
                SYSTEM="x86_64-darwin"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if [[ "$(uname -m)" == "aarch64" ]]; then
                SYSTEM="aarch64-linux"
            else
                SYSTEM="x86_64-linux"
            fi
        else
            log_error "Unsupported system type: $OSTYPE"
            exit 1
        fi
    fi
    
    if [[ -z "$HOSTNAME" ]]; then
        HOSTNAME="$(hostname -s)"
    fi
    
    log_verbose "Detected system: $SYSTEM"
    log_verbose "Detected hostname: $HOSTNAME"
}

# Check if required tools are available
check_dependencies() {
    log_verbose "Checking dependencies..."
    
    if ! command -v nix &> /dev/null; then
        log_error "Nix is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not available - JSON output will be raw"
    fi
    
    log_verbose "Dependencies check passed"
}

# Validate flake structure
validate_flake() {
    log_info "Validating flake structure..."
    
    if [[ ! -f "$PROJECT_ROOT/flake.nix" ]]; then
        log_error "flake.nix not found in project root"
        exit 1
    fi
    
    if [[ ! -f "$PROJECT_ROOT/flake.lock" ]]; then
        log_warning "flake.lock not found - run 'nix flake update' first"
    fi
    
    # Check if flake is valid
    if ! nix flake check "$PROJECT_ROOT" --no-build 2>/dev/null; then
        log_error "Flake validation failed"
        return 1
    fi
    
    log_success "Flake structure is valid"
    return 0
}

# Validate configuration using Nix evaluation
validate_configuration() {
    log_info "Validating configuration for $HOSTNAME ($SYSTEM)..."
    
    local validation_expr="
    let
      flake = builtins.getFlake \"$PROJECT_ROOT\";
      
      # Try to get the system configuration
      systemConfig = 
        if builtins.hasAttr \"darwinConfigurations\" flake.outputs &&
           builtins.hasAttr \"$HOSTNAME\" flake.outputs.darwinConfigurations
        then flake.outputs.darwinConfigurations.$HOSTNAME.config
        else if builtins.hasAttr \"nixosConfigurations\" flake.outputs &&
                builtins.hasAttr \"$HOSTNAME\" flake.outputs.nixosConfigurations  
        then flake.outputs.nixosConfigurations.$HOSTNAME.config
        else throw \"Configuration for host '$HOSTNAME' not found\";
      
      # Extract the user configuration parts that we can validate
      config = {
        hostname = systemConfig.networking.hostName or \"$HOSTNAME\";
        system = \"$SYSTEM\";
        username = \"le\"; # TODO: Extract from actual config
        modules = systemConfig.modules or {};
        profiles = systemConfig.profiles or {};
      };
      
      # Import validation library
      validation = import $PROJECT_ROOT/lib/validation.nix {
        inputs = flake.inputs;
        outputs = flake.outputs;
        stateVersion = \"23.11\"; # Default state version
      };
      
      # Run validation
      result = validation.configValidation.validateFullConfig config \"$SYSTEM\";
      
      # Format result
      formatResult = result: {
        valid = result.valid;
        summary = result.summary;
        errors = result.errors;
        errorsByCategory = result.results.modules.errorsByCategory or {};
      };
      
    in formatResult result
    "
    
    log_verbose "Running validation expression..."
    
    local validation_output
    if ! validation_output=$(nix eval --impure --json --expr "$validation_expr" 2>&1); then
        log_error "Configuration validation failed to run:"
        echo "$validation_output" >&2
        return 1
    fi
    
    log_verbose "Validation completed, processing results..."
    
    # Parse validation results
    local is_valid
    local error_count
    local errors
    
    if command -v jq &> /dev/null; then
        is_valid=$(echo "$validation_output" | jq -r '.valid')
        error_count=$(echo "$validation_output" | jq -r '.summary.totalErrors')
        errors=$(echo "$validation_output" | jq -r '.errors[]?' 2>/dev/null || echo "")
    else
        # Fallback parsing without jq
        is_valid=$(echo "$validation_output" | grep -o '"valid":[^,}]*' | cut -d: -f2 | tr -d ' "')
        error_count=$(echo "$validation_output" | grep -o '"totalErrors":[^,}]*' | cut -d: -f2 | tr -d ' "')
        errors=$(echo "$validation_output" | grep -o '"errors":\[[^]]*\]' | sed 's/"errors":\[//; s/\]$//; s/","/\n/g; s/"//g')
    fi
    
    # Display results
    if [[ "$is_valid" == "true" ]]; then
        log_success "Configuration validation passed!"
        return 0
    else
        log_error "Configuration validation failed with $error_count error(s):"
        if [[ -n "$errors" ]]; then
            while IFS= read -r error; do
                [[ -n "$error" ]] && echo "  - $error"
            done <<< "$errors"
        fi
        return 1
    fi
}

# Generate validation report
generate_report() {
    if [[ "$GENERATE_REPORT" != "true" ]]; then
        return 0
    fi
    
    log_info "Generating validation report..."
    
    local report_expr="
    let
      flake = builtins.getFlake \"$PROJECT_ROOT\";
      
      config = 
        if builtins.hasAttr \"darwinConfigurations\" flake.outputs &&
           builtins.hasAttr \"$HOSTNAME\" flake.outputs.darwinConfigurations
        then flake.outputs.darwinConfigurations.$HOSTNAME.config
        else if builtins.hasAttr \"nixosConfigurations\" flake.outputs &&
                builtins.hasAttr \"$HOSTNAME\" flake.outputs.nixosConfigurations  
        then flake.outputs.nixosConfigurations.$HOSTNAME.config
        else throw \"Configuration for host '$HOSTNAME' not found\";
      
      validation = import $PROJECT_ROOT/lib/validation.nix {
        inputs = flake.inputs;
        outputs = flake.outputs;
        stateVersion = \"23.11\";
      };
      
      result = validation.configValidation.validateFullConfig config \"$SYSTEM\";
      
      # Generate report
      report = ''
        Configuration Validation Report
        =============================
        
        Timestamp: \${toString builtins.currentTime}
        System: $SYSTEM
        Hostname: $HOSTNAME
        
        Summary:
        - Total Errors: \${toString result.summary.totalErrors}
        - Host Errors: \${toString result.summary.hostErrors}
        - Profile Errors: \${toString result.summary.profileErrors}
        - Module Errors: \${toString result.summary.moduleErrors}
        
        \${if result.summary.totalErrors > 0 then ''
        Errors:
        \${builtins.concatStringsSep \"\n\" (map (error: \"- \${error}\") result.errors)}
        '' else \"\"}
        
        \${if result.valid then \"✅ Configuration is valid!\" else \"❌ Configuration has validation errors\"}
        
        Module Validation Details:
        ========================
        
        Structure Errors: \${toString (builtins.length (result.results.modules.errorsByCategory.structure or []))}
        Dependency Errors: \${toString (builtins.length (result.results.modules.errorsByCategory.dependencies or []))}
        Platform Errors: \${toString (builtins.length (result.results.modules.errorsByCategory.platform or []))}
      '';
      
    in report
    "
    
    local report_content
    if report_content=$(nix eval --impure --raw --expr "$report_expr" 2>&1); then
        echo "$report_content" > "$VALIDATION_REPORT"
        log_success "Validation report written to: $VALIDATION_REPORT"
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo ""
            echo "Report contents:"
            echo "================"
            cat "$VALIDATION_REPORT"
        fi
    else
        log_error "Failed to generate validation report:"
        echo "$report_content" >&2
        return 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -H|--hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            -s|--system)
                SYSTEM="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--check-only)
                CHECK_ONLY=true
                GENERATE_REPORT=false
                shift
                ;;
            -r|--report)
                VALIDATION_REPORT="$2"
                shift 2
                ;;
            --no-report)
                GENERATE_REPORT=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"
    
    log_info "Starting configuration validation..."
    
    detect_system
    check_dependencies
    
    # Validate flake structure
    if ! validate_flake; then
        exit 1
    fi
    
    # Validate configuration
    local validation_success=true
    if ! validate_configuration; then
        validation_success=false
    fi
    
    # Generate report if requested
    if [[ "$CHECK_ONLY" != "true" ]]; then
        generate_report
    fi
    
    # Exit with appropriate code
    if [[ "$validation_success" == "true" ]]; then
        log_success "All validation checks passed!"
        exit 0
    else
        log_error "Validation failed - check errors above"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"