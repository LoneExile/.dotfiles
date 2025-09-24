#!/usr/bin/env bash

# Final validation script for modular Nix configuration
# This script performs comprehensive checks to ensure the system is working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Main validation function
main() {
    log_info "Starting final validation of modular Nix configuration..."
    echo
    
    # Test 1: Flake syntax validation
    run_test "Flake syntax check" "nix flake check --no-build"
    
    # Test 2: Library functions
    run_test "Library mkDarwin function" "nix eval .#lib.mkDarwin --apply 'f: builtins.isFunction f'"
    
    # Test 3: Darwin configuration build
    run_test "Darwin configuration build test" "nix build .#darwinConfigurations.le.system --dry-run"
    
    # Test 4: Development shell
    run_test "Development shell availability" "nix develop --command echo 'dev shell works'"
    
    # Test 5: Package utilities
    run_test "Validation package" "nix eval .#packages.aarch64-darwin.validate-config --apply 'p: p.name or \"validate-config\"'"
    
    # Test 6: Templates
    run_test "Template availability" "nix eval .#templates.default.description --raw"
    
    # Test 7: Module system
    run_test "Module system integration" "nix eval '.#darwinConfigurations.le.config' --apply 'x: builtins.isAttrs x'"
    
    # Test 8: Profile system  
    run_test "Profile system" "nix eval '.#darwinConfigurations.le.system' --apply 'x: builtins.isString x.drvPath'"
    
    # Test 9: Documentation structure
    run_test "Documentation files" "test -f docs/SETUP.md && test -f docs/MODULES.md && test -f docs/TROUBLESHOOTING.md"
    
    # Test 10: Justfile commands
    run_test "Justfile availability" "test -f justfile"
    
    echo
    log_info "Validation Summary:"
    echo "  Tests run: $TESTS_RUN"
    echo "  Tests passed: $TESTS_PASSED"
    echo "  Tests failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo
        log_success "🎉 All validation tests passed! The modular Nix configuration is ready for use."
        echo
        log_info "Next steps:"
        echo "  1. Customize your host configuration in hosts/$(hostname)/"
        echo "  2. Run 'just switch' to apply the configuration"
        echo "  3. Explore available modules and profiles"
        echo "  4. Check out the documentation in docs/"
        return 0
    else
        echo
        log_error "❌ Some validation tests failed. Please review the errors above."
        return 1
    fi
}

# Run main function
main "$@"