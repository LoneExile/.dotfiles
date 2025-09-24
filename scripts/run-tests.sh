#!/usr/bin/env bash

# Test runner script for modular Nix configuration
# This script provides a convenient way to run different test suites

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
TEST_SUITE="all"
PARALLEL=false
TIMEOUT=300
VERBOSE=false
SYSTEM="aarch64-darwin"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_SUITE]

Run tests for the modular Nix configuration.

TEST_SUITE options:
    all             Run all test suites (default)
    unit            Run unit tests only
    integration     Run integration tests only
    system          Run system tests only
    modules         Run module tests only
    lib             Run library tests only
    profiles        Run profile tests only
    hosts           Run host configuration tests only

OPTIONS:
    -p, --parallel      Run tests in parallel where possible
    -t, --timeout SEC   Set timeout for individual tests (default: 300)
    -s, --system SYS    Target system (default: aarch64-darwin)
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

Examples:
    $0                          # Run all tests
    $0 unit                     # Run unit tests only
    $0 --parallel integration   # Run integration tests in parallel
    $0 --timeout 600 system     # Run system tests with 10min timeout

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
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
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option $1"
            show_help
            exit 1
            ;;
        *)
            TEST_SUITE="$1"
            shift
            ;;
    esac
done

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

# Check if we're in a Nix environment
check_nix_environment() {
    if ! command -v nix &> /dev/null; then
        log_error "Nix is not available. Please install Nix first."
        exit 1
    fi
    
    if ! nix flake check --no-build 2>/dev/null; then
        log_warning "Flake check failed. Some tests might not work correctly."
    fi
}

# Build test infrastructure
build_test_infrastructure() {
    log_info "Building test infrastructure..."
    
    if [[ "$VERBOSE" == "true" ]]; then
        nix build ".#tests" --system "$SYSTEM"
    else
        nix build ".#tests" --system "$SYSTEM" --quiet
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "Test infrastructure built successfully"
    else
        log_error "Failed to build test infrastructure"
        exit 1
    fi
}

# Run specific test suite
run_test_suite() {
    local suite="$1"
    local parallel_flag=""
    
    if [[ "$PARALLEL" == "true" ]]; then
        parallel_flag="--parallel"
    fi
    
    log_info "Running $suite tests..."
    
    case "$suite" in
        "unit")
            nix run ".#tests.unit.runTests" --system "$SYSTEM"
            ;;
        "integration")
            nix run ".#tests.integration.runTests" --system "$SYSTEM"
            ;;
        "system")
            nix run ".#tests.system.runTests" --system "$SYSTEM"
            ;;
        "modules")
            nix run ".#tests.unit.modules.runTests" --system "$SYSTEM"
            ;;
        "lib")
            nix run ".#tests.unit.lib.runTests" --system "$SYSTEM"
            ;;
        "profiles")
            nix run ".#tests.integration.profiles.runTests" --system "$SYSTEM"
            ;;
        "hosts")
            nix run ".#tests.integration.hosts.runTests" --system "$SYSTEM"
            ;;
        "all")
            nix run ".#tests.runAll" --system "$SYSTEM"
            ;;
        *)
            log_error "Unknown test suite: $suite"
            show_help
            exit 1
            ;;
    esac
}

# Main execution
main() {
    log_info "Starting test execution for modular Nix configuration"
    log_info "Test suite: $TEST_SUITE"
    log_info "System: $SYSTEM"
    log_info "Parallel: $PARALLEL"
    log_info "Timeout: ${TIMEOUT}s"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Check environment
    check_nix_environment
    
    # Build test infrastructure
    build_test_infrastructure
    
    # Run tests
    local start_time=$(date +%s)
    
    if run_test_suite "$TEST_SUITE"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "All tests completed successfully in ${duration}s"
        exit 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "Tests failed after ${duration}s"
        exit 1
    fi
}

# Run main function
main "$@"