#!/usr/bin/env bash
# NixOS Configuration Test Runner
# Executes all integration tests with proper error handling and reporting

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_TEST_NAMES=()

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
LOG_DIR="${BUILD_DIR}/logs"
FLAKE_REF="${REPO_ROOT}#"

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    local deps=("nix" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            print_error "Missing dependency: $dep"
            exit 1
        fi
    done
    
    # Check for experimental features
    if ! nix --version &> /dev/null; then
        print_error "Nix experimental features not enabled"
        print_info "Enable with: nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];"
        exit 1
    fi
    
    print_success "All dependencies satisfied"
}

# Setup test environment
setup_environment() {
    print_info "Setting up test environment..."
    
    # Create directories
    mkdir -p "$LOG_DIR"
    
    # Clean previous builds
    if [ -d "$BUILD_DIR/result" ]; then
        rm -rf "$BUILD_DIR/result"
    fi
    
    print_success "Test environment ready"
}

# Run a single test
run_test() {
    local test_name="$1"
    local log_file="${LOG_DIR}/${test_name}.log"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    print_info "Running test: $test_name"
    
    if nix build "${FLAKE_REF}checks.x86_64-linux.${test_name}" \
        --no-link \
        --print-out-paths \
        --show-trace \
        &> "$log_file"; then
        
        PASSED_TESTS=$((PASSED_TESTS + 1))
        print_success "Test passed: $test_name"
        return 0
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$test_name")
        print_error "Test failed: $test_name (see $log_file)"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    print_info "Discovering tests..."
    
    # Get list of all tests from flake
    local tests
    tests=$(nix flake show --json 2>/dev/null | \
        jq -r '.checks."x86_64-linux" | keys[]' 2>/dev/null || true)
    
    if [ -z "$tests" ]; then
        print_warning "No tests found in flake"
        return 0
    fi
    
    print_info "Found $(echo "$tests" | wc -l) tests"
    echo
    
    # Run each test
    while IFS= read -r test; do
        run_test "$test" || true
        echo
    done <<< "$tests"
}

# Run specific test
run_specific_test() {
    local test_name="$1"
    
    if run_test "$test_name"; then
        return 0
    else
        return 1
    fi
}

# Generate test report
generate_report() {
    echo
    echo "=================================="
    echo "        TEST SUMMARY REPORT       "
    echo "=================================="
    echo
    echo "Total tests:  $TOTAL_TESTS"
    echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
    echo
    
    if [ ${#FAILED_TEST_NAMES[@]} -gt 0 ]; then
        echo "Failed tests:"
        for test in "${FAILED_TEST_NAMES[@]}"; do
            echo "  - $test"
        done
        echo
        echo "Check logs in: $LOG_DIR"
        echo
    fi
    
    if [ $FAILED_TESTS -eq 0 ] && [ $TOTAL_TESTS -gt 0 ]; then
        print_success "All tests passed! 🎉"
        return 0
    elif [ $TOTAL_TESTS -eq 0 ]; then
        print_warning "No tests were run"
        return 0
    else
        print_error "Some tests failed"
        return 1
    fi
}

# Interactive test runner
interactive_mode() {
    echo "NixOS Configuration Test Runner - Interactive Mode"
    echo "=================================================="
    echo
    echo "Available tests:"
    
    # Get list of tests
    local tests
    tests=$(nix flake show --json 2>/dev/null | \
        jq -r '.checks."x86_64-linux" | keys[]' 2>/dev/null || true)
    
    if [ -z "$tests" ]; then
        print_warning "No tests found"
        return 1
    fi
    
    # Display tests with numbers
    local i=1
    declare -a test_array
    while IFS= read -r test; do
        echo "  $i) $test"
        test_array[i]="$test"
        i=$((i + 1))
    done <<< "$tests"
    
    echo "  a) Run all tests"
    echo "  q) Quit"
    echo
    
    while true; do
        read -p "Select test to run: " choice
        
        case $choice in
            q|Q)
                echo "Exiting..."
                return 0
                ;;
            a|A)
                run_all_tests
                generate_report
                return $?
                ;;
            [0-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
                    run_specific_test "${test_array[$choice]}"
                    echo
                else
                    print_error "Invalid selection"
                fi
                ;;
            *)
                print_error "Invalid selection"
                ;;
        esac
    done
}

# Main function
main() {
    echo "NixOS Configuration Test Runner"
    echo "==============================="
    echo
    
    # Parse arguments
    case "${1:-}" in
        -h|--help)
            echo "Usage: $0 [OPTIONS] [TEST_NAME]"
            echo
            echo "Options:"
            echo "  -h, --help      Show this help message"
            echo "  -i, --interactive  Run in interactive mode"
            echo "  -l, --list      List available tests"
            echo
            echo "Examples:"
            echo "  $0              # Run all tests"
            echo "  $0 vm-profile   # Run specific test"
            echo "  $0 -i           # Interactive mode"
            exit 0
            ;;
        -i|--interactive)
            check_dependencies
            setup_environment
            interactive_mode
            exit $?
            ;;
        -l|--list)
            nix flake show --json 2>/dev/null | \
                jq -r '.checks."x86_64-linux" | keys[]' 2>/dev/null || \
                print_error "No tests found"
            exit 0
            ;;
        "")
            # Run all tests
            check_dependencies
            setup_environment
            run_all_tests
            generate_report
            exit $?
            ;;
        *)
            # Run specific test
            check_dependencies
            setup_environment
            run_specific_test "$1"
            generate_report
            exit $?
            ;;
    esac
}

# Run main function
main "$@"