#!/usr/bin/env bash

# Configuration diagnostics and error analysis script
# Provides comprehensive analysis of Nix configuration issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIAGNOSTIC_REPORT="/tmp/nix-config-diagnostics.txt"
ERROR_LOG="/tmp/nix-config-errors.log"

# Default values
HOSTNAME=""
SYSTEM=""
VERBOSE=false
INTERACTIVE=false
FIX_MODE=false
HEALTH_CHECK=true

# Help function
show_help() {
    cat << EOF
Configuration Diagnostics and Error Analysis Script

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    health          Run health check and show summary
    validate        Run full validation with detailed errors
    analyze         Analyze configuration and suggest fixes
    debug MODULE    Debug specific module configuration
    profile         Profile build performance
    fix             Interactive fix mode (experimental)

OPTIONS:
    -h, --help              Show this help message
    -H, --hostname HOSTNAME Specify hostname (default: auto-detect)
    -s, --system SYSTEM     Specify system type (default: auto-detect)
    -v, --verbose           Enable verbose output
    -i, --interactive       Interactive mode with prompts
    -f, --fix               Attempt automatic fixes (experimental)
    --no-health             Skip health check
    --report PATH           Custom diagnostic report path

EXAMPLES:
    $0 health               # Quick health check
    $0 validate -v          # Detailed validation with verbose output
    $0 analyze              # Analyze issues and get suggestions
    $0 debug modules.home.development.git  # Debug specific module
    $0 profile              # Profile build performance
    $0 fix -i               # Interactive fix mode

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

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
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
    
    log_debug "System: $SYSTEM, Hostname: $HOSTNAME"
}

# Check dependencies
check_dependencies() {
    log_debug "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v nix &> /dev/null; then
        missing_deps+=("nix")
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq not available - some features will be limited"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    log_debug "Dependencies check passed"
}

# Run health check
run_health_check() {
    log_step "Running system health check..."
    
    local health_expr="
    let
      flake = builtins.getFlake \"$PROJECT_ROOT\";
      
      # Try to get the system configuration
      systemConfig = 
        if builtins.hasAttr \"darwinConfigurations\" flake.outputs &&
           builtins.hasAttr \"$HOSTNAME\" flake.outputs.darwinConfigurations
        then flake.outputs.darwinConfigurations.$HOSTNAME.config
        else throw \"Configuration for host '$HOSTNAME' not found\";
      
      # Extract the user configuration parts that we can validate
      config = {
        hostname = systemConfig.networking.hostName or \"$HOSTNAME\";
        system = \"$SYSTEM\";
        username = \"le\"; # TODO: Extract from actual config
        modules = systemConfig.modules or {};
        profiles = systemConfig.profiles or {};
      };
      
      errorLib = import $PROJECT_ROOT/lib/error-handling.nix {
        inputs = flake.inputs;
        outputs = flake.outputs;
        stateVersion = \"23.11\";
      };
      
      healthCheck = errorLib.diagnostics.healthCheck config \"$SYSTEM\";
      
    in {
      score = healthCheck.score;
      status = healthCheck.status;
      totalModules = healthCheck.dependencies.totalModules;
      issueCount = healthCheck.dependencies.issueCount;
      errorCount = healthCheck.validation.summary.totalErrors;
      recommendations = healthCheck.recommendations;
    }
    "
    
    local health_result
    if ! health_result=$(nix eval --impure --json --expr "$health_expr" 2>"$ERROR_LOG"); then
        log_error "Health check failed:"
        cat "$ERROR_LOG" >&2
        return 1
    fi
    
    # Parse results
    local score status total_modules issue_count error_count
    if command -v jq &> /dev/null; then
        score=$(echo "$health_result" | jq -r '.score')
        status=$(echo "$health_result" | jq -r '.status')
        total_modules=$(echo "$health_result" | jq -r '.totalModules')
        issue_count=$(echo "$health_result" | jq -r '.issueCount')
        error_count=$(echo "$health_result" | jq -r '.errorCount')
        
        echo ""
        echo "🏥 System Health Report"
        echo "======================"
        echo ""
        
        # Health score with color coding
        if [[ "$score" -ge 90 ]]; then
            echo -e "Health Score: ${GREEN}$score/100${NC} ($status)"
        elif [[ "$score" -ge 75 ]]; then
            echo -e "Health Score: ${YELLOW}$score/100${NC} ($status)"
        else
            echo -e "Health Score: ${RED}$score/100${NC} ($status)"
        fi
        
        echo "Modules: $total_modules total, $issue_count with issues"
        echo "Validation: $error_count errors"
        
        # Show recommendations if any
        local recommendations
        recommendations=$(echo "$health_result" | jq -r '.recommendations[]?' 2>/dev/null || echo "")
        if [[ -n "$recommendations" ]]; then
            echo ""
            echo "💡 Recommendations:"
            while IFS= read -r rec; do
                [[ -n "$rec" ]] && echo "  - $rec"
            done <<< "$recommendations"
        fi
        
        echo ""
        
        # Return appropriate exit code
        if [[ "$error_count" -gt 0 ]]; then
            return 1
        else
            return 0
        fi
    else
        echo "Health check completed (install jq for detailed results)"
        return 0
    fi
}

# Run full validation
run_validation() {
    log_step "Running configuration validation..."
    
    # Use the existing validation script
    if [[ -x "$SCRIPT_DIR/validate-config.sh" ]]; then
        local validate_args=()
        [[ "$VERBOSE" == "true" ]] && validate_args+=("-v")
        [[ -n "$HOSTNAME" ]] && validate_args+=("-H" "$HOSTNAME")
        [[ -n "$SYSTEM" ]] && validate_args+=("-s" "$SYSTEM")
        
        "$SCRIPT_DIR/validate-config.sh" "${validate_args[@]}"
    else
        log_error "Validation script not found: $SCRIPT_DIR/validate-config.sh"
        return 1
    fi
}

# Analyze configuration and suggest fixes
analyze_configuration() {
    log_step "Analyzing configuration for issues..."
    
    local analysis_expr="
    let
      flake = builtins.getFlake \"$PROJECT_ROOT\";
      
      # Try to get the system configuration
      systemConfig = 
        if builtins.hasAttr \"darwinConfigurations\" flake.outputs &&
           builtins.hasAttr \"$HOSTNAME\" flake.outputs.darwinConfigurations
        then flake.outputs.darwinConfigurations.$HOSTNAME.config
        else throw \"Configuration for host '$HOSTNAME' not found\";
      
      # Extract the user configuration parts that we can validate
      config = {
        hostname = systemConfig.networking.hostName or \"$HOSTNAME\";
        system = \"$SYSTEM\";
        username = \"le\"; # TODO: Extract from actual config
        modules = systemConfig.modules or {};
        profiles = systemConfig.profiles or {};
      };
      
      validationLib = import $PROJECT_ROOT/lib/validation.nix {
        inputs = flake.inputs;
        outputs = flake.outputs;
        stateVersion = \"23.11\";
      };
      
      errorLib = import $PROJECT_ROOT/lib/error-handling.nix {
        inputs = flake.inputs;
        outputs = flake.outputs;
        stateVersion = \"23.11\";
      };
      
      validationResult = validationLib.configValidation.validateFullConfig config \"$SYSTEM\";
      repairs = errorLib.recovery.suggestRepairs validationResult.errors;
      depAnalysis = errorLib.diagnostics.analyzeDependencies config;
      
    in {
      validation = validationResult;
      repairs = repairs;
      dependencies = depAnalysis;
    }
    "
    
    local analysis_result
    if ! analysis_result=$(nix eval --impure --json --expr "$analysis_expr" 2>"$ERROR_LOG"); then
        log_error "Configuration analysis failed:"
        cat "$ERROR_LOG" >&2
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        echo ""
        echo "🔍 Configuration Analysis"
        echo "========================"
        echo ""
        
        # Show validation summary
        local total_errors
        total_errors=$(echo "$analysis_result" | jq -r '.validation.summary.totalErrors')
        
        if [[ "$total_errors" -gt 0 ]]; then
            echo -e "${RED}Found $total_errors validation error(s):${NC}"
            echo ""
            
            # Show errors with repair suggestions
            echo "$analysis_result" | jq -r '.repairs[] | "❌ " + .error + "\n💡 " + .suggestion + "\n"'
        else
            echo -e "${GREEN}✅ No validation errors found${NC}"
        fi
        
        # Show dependency analysis
        local issue_count
        issue_count=$(echo "$analysis_result" | jq -r '.dependencies.issueCount')
        
        if [[ "$issue_count" -gt 0 ]]; then
            echo ""
            echo -e "${YELLOW}Found $issue_count module dependency issue(s):${NC}"
            echo ""
            
            echo "$analysis_result" | jq -r '
              .dependencies.modules[] | 
              select(.hasIssues) | 
              "🔗 " + .module + 
              (if .missingDependencies != [] then "\n   Missing: " + (.missingDependencies | join(", ")) else "" end) +
              (if .activeConflicts != [] then "\n   Conflicts: " + (.activeConflicts | join(", ")) else "" end) +
              "\n"
            '
        fi
        
        echo ""
        return $(( total_errors > 0 ? 1 : 0 ))
    else
        echo "Analysis completed (install jq for detailed results)"
        return 0
    fi
}

# Debug specific module
debug_module() {
    local module_path="$1"
    
    if [[ -z "$module_path" ]]; then
        log_error "Module path required for debugging"
        echo "Usage: $0 debug <module-path>"
        echo "Example: $0 debug modules.home.development.git"
        return 1
    fi
    
    log_step "Debugging module: $module_path"
    
    local debug_expr="
    let
      flake = builtins.getFlake \"$PROJECT_ROOT\";
      config = 
        if builtins.hasAttr \"darwinConfigurations\" flake.outputs &&
           builtins.hasAttr \"$HOSTNAME\" flake.outputs.darwinConfigurations
        then flake.outputs.darwinConfigurations.$HOSTNAME.config
        else throw \"Configuration for host '$HOSTNAME' not found\";
      
      pathParts = builtins.filter (x: x != \"\") (builtins.split \"\\.\" \"$module_path\");
      moduleConfig = builtins.foldl' (acc: part: 
        if builtins.hasAttr part acc 
        then acc.\${part} 
        else throw \"Path '$module_path' not found in configuration\"
      ) config pathParts;
      
    in {
      enabled = moduleConfig.enable or false;
      hasPackage = builtins.hasAttr \"package\" moduleConfig;
      hasSettings = builtins.hasAttr \"settings\" moduleConfig;
      settingsKeys = if builtins.hasAttr \"settings\" moduleConfig 
                    then builtins.attrNames moduleConfig.settings 
                    else [];
      hasExtraConfig = builtins.hasAttr \"extraConfig\" moduleConfig;
      moduleType = builtins.typeOf moduleConfig;
    }
    "
    
    local debug_result
    if ! debug_result=$(nix eval --impure --json --expr "$debug_expr" 2>"$ERROR_LOG"); then
        log_error "Module debugging failed:"
        cat "$ERROR_LOG" >&2
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        echo ""
        echo "🐛 Module Debug Information"
        echo "=========================="
        echo ""
        echo "Module: $module_path"
        
        local enabled has_package has_settings has_extra_config
        enabled=$(echo "$debug_result" | jq -r '.enabled')
        has_package=$(echo "$debug_result" | jq -r '.hasPackage')
        has_settings=$(echo "$debug_result" | jq -r '.hasSettings')
        has_extra_config=$(echo "$debug_result" | jq -r '.hasExtraConfig')
        
        echo "Enabled: $enabled"
        echo "Has package: $has_package"
        echo "Has settings: $has_settings"
        echo "Has extraConfig: $has_extra_config"
        
        local settings_keys
        settings_keys=$(echo "$debug_result" | jq -r '.settingsKeys[]?' 2>/dev/null || echo "")
        if [[ -n "$settings_keys" ]]; then
            echo ""
            echo "Settings keys:"
            while IFS= read -r key; do
                [[ -n "$key" ]] && echo "  - $key"
            done <<< "$settings_keys"
        fi
        
        echo ""
    else
        echo "Module debug completed (install jq for detailed results)"
    fi
}

# Profile build performance
profile_build() {
    log_step "Profiling build performance..."
    
    local start_time
    start_time=$(date +%s)
    
    echo "Building configuration (this may take a while)..."
    
    local build_log="/tmp/nix-build-profile-$$.log"
    
    if nix build --no-link --print-build-logs \
        "$PROJECT_ROOT#darwinConfigurations.$HOSTNAME.system" \
        2>&1 | tee "$build_log"; then
        
        local end_time duration
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        echo ""
        echo "⏱️  Build Performance Report"
        echo "==========================="
        echo ""
        echo "Total build time: ${duration}s"
        
        # Analyze build log
        local derivations_built
        derivations_built=$(grep -c "building '/nix/store" "$build_log" 2>/dev/null || echo "0")
        echo "Derivations built: $derivations_built"
        
        # Find potential performance issues
        if [[ "$derivations_built" -gt 50 ]]; then
            log_warning "High number of derivations built - consider using binary cache"
        fi
        
        if [[ "$duration" -gt 300 ]]; then
            log_warning "Build took over 5 minutes - consider optimizing configuration"
        fi
        
        echo ""
        echo "Build log saved to: $build_log"
        
    else
        log_error "Build failed - check build log: $build_log"
        return 1
    fi
}

# Interactive fix mode (experimental)
interactive_fix() {
    log_step "Starting interactive fix mode..."
    log_warning "This is experimental - review all changes carefully"
    
    # First run analysis to get issues
    local analysis_expr="
    let
      flake = builtins.getFlake \"$PROJECT_ROOT\";
      config = 
        if builtins.hasAttr \"darwinConfigurations\" flake.outputs &&
           builtins.hasAttr \"$HOSTNAME\" flake.outputs.darwinConfigurations
        then flake.outputs.darwinConfigurations.$HOSTNAME.config
        else throw \"Configuration for host '$HOSTNAME' not found\";
      
      validationLib = import $PROJECT_ROOT/lib/validation.nix {
        inputs = flake.inputs;
        outputs = flake.outputs;
        stateVersion = \"23.11\";
      };
      
      validationResult = validationLib.configValidation.validateFullConfig config \"$SYSTEM\";
      
    in validationResult.errors
    "
    
    local errors
    if ! errors=$(nix eval --impure --json --expr "$analysis_expr" 2>"$ERROR_LOG"); then
        log_error "Could not analyze configuration for fixes:"
        cat "$ERROR_LOG" >&2
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        local error_count
        error_count=$(echo "$errors" | jq -r 'length')
        
        if [[ "$error_count" -eq 0 ]]; then
            log_success "No errors found to fix!"
            return 0
        fi
        
        echo ""
        echo "Found $error_count error(s) to potentially fix:"
        echo ""
        
        # Show errors and ask for fixes
        local i=0
        while IFS= read -r error; do
            [[ -z "$error" ]] && continue
            i=$((i + 1))
            
            echo "Error $i: $error"
            
            if [[ "$INTERACTIVE" == "true" ]]; then
                echo -n "Attempt to fix this error? [y/N]: "
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    log_info "Fix functionality not yet implemented for: $error"
                fi
            fi
            
            echo ""
        done < <(echo "$errors" | jq -r '.[]?')
        
    else
        log_error "jq required for interactive fix mode"
        return 1
    fi
}

# Parse command line arguments
parse_args() {
    local command=""
    
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
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -f|--fix)
                FIX_MODE=true
                shift
                ;;
            --no-health)
                HEALTH_CHECK=false
                shift
                ;;
            --report)
                DIAGNOSTIC_REPORT="$2"
                shift 2
                ;;
            health|validate|analyze|debug|profile|fix)
                command="$1"
                shift
                break
                ;;
            *)
                if [[ -z "$command" ]]; then
                    log_error "Unknown option or command: $1"
                    show_help
                    exit 1
                fi
                break
                ;;
        esac
    done
    
    # Set default command
    if [[ -z "$command" ]]; then
        command="health"
    fi
    
    # Execute command
    case "$command" in
        health)
            run_health_check
            ;;
        validate)
            run_validation
            ;;
        analyze)
            analyze_configuration
            ;;
        debug)
            debug_module "$1"
            ;;
        profile)
            profile_build
            ;;
        fix)
            interactive_fix
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Main function
main() {
    detect_system
    check_dependencies
    
    parse_args "$@"
}

# Run main function with all arguments
main "$@"