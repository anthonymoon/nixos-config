#!/usr/bin/env bash
# Test-Driven Development Workflow for NixOS Configuration
# Implements TDD cycle: Red -> Green -> Refactor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[TDD]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# TDD Workflow Functions
tdd_red() {
    step "RED: Write failing test"
    echo "This phase focuses on writing tests that fail initially"
    echo "Tests should define the expected behavior before implementation"
    echo ""
    echo "Example workflow:"
    echo "1. Add a new test case for desired functionality"
    echo "2. Run tests to confirm they fail (RED state)"
    echo "3. Commit the failing test as a baseline"
    echo ""
    read -p "Press Enter when you've added failing tests..."
    
    log "Running test suite to confirm RED state..."
    if "$SCRIPT_DIR/test-runner.sh" run syntax build; then
        warn "Tests are passing - ensure you've added failing tests first"
    else
        log "✅ Tests are failing as expected (RED state)"
    fi
}

tdd_green() {
    step "GREEN: Make tests pass with minimal implementation"
    echo "This phase focuses on making tests pass with the simplest solution"
    echo "Avoid over-engineering - just make the tests pass"
    echo ""
    echo "Example workflow:"
    echo "1. Implement minimal code to make tests pass"
    echo "2. Run tests frequently to check progress"
    echo "3. Stop when all tests pass (GREEN state)"
    echo ""
    read -p "Press Enter when you've implemented the feature..."
    
    log "Running test suite to confirm GREEN state..."
    if "$SCRIPT_DIR/test-runner.sh" run syntax build; then
        log "✅ Tests are passing (GREEN state)"
    else
        error "Tests are still failing - continue implementation"
        return 1
    fi
}

tdd_refactor() {
    step "REFACTOR: Improve code while keeping tests green"
    echo "This phase focuses on improving code quality without changing behavior"
    echo "Tests should remain green throughout refactoring"
    echo ""
    echo "Example improvements:"
    echo "1. Remove code duplication"
    echo "2. Improve naming and structure"
    echo "3. Optimize performance"
    echo "4. Enhance documentation"
    echo ""
    read -p "Press Enter when you've completed refactoring..."
    
    log "Running full test suite to ensure refactoring didn't break anything..."
    if "$SCRIPT_DIR/test-runner.sh" run full; then
        log "✅ All tests still passing after refactor"
    else
        error "Refactoring broke tests - revert changes"
        return 1
    fi
}

# Automated TDD helpers
tdd_watch() {
    log "Starting TDD watch mode..."
    echo "Watching for file changes and running tests automatically"
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Use inotify to watch for file changes
    if ! command -v inotifywait >/dev/null 2>&1; then
        error "inotifywait not found. Install inotify-tools package."
        return 1
    fi
    
    while true; do
        inotifywait -r -e modify,create,delete \
            "$ROOT_DIR"/{flake.nix,profiles,modules} \
            >/dev/null 2>&1
        
        echo -e "${CYAN}[CHANGE DETECTED]${NC} Running tests..."
        "$SCRIPT_DIR/test-runner.sh" run syntax build
        echo "----------------------------------------"
    done
}

tdd_quick_test() {
    log "Running quick test cycle (syntax + build only)"
    "$SCRIPT_DIR/test-runner.sh" run syntax
    "$SCRIPT_DIR/test-runner.sh" run build
}

tdd_full_test() {
    log "Running complete test cycle"
    "$SCRIPT_DIR/test-runner.sh" run full
}

tdd_vm_test() {
    log "Running VM integration tests"
    
    # Restore VM to clean state
    "$SCRIPT_DIR/test-runner.sh" vm-restore
    
    # Run installation test
    "$SCRIPT_DIR/test-runner.sh" run install
    
    # Run module tests
    "$SCRIPT_DIR/test-modules.sh" all
}

# Development workflow helpers
dev_new_feature() {
    local feature_name="$1"
    
    log "Starting development of new feature: $feature_name"
    
    # Create feature branch
    git checkout -b "feature/$feature_name" 2>/dev/null || true
    
    echo ""
    echo "TDD Workflow for '$feature_name':"
    echo "1. Write failing tests (RED)"
    echo "2. Implement minimal solution (GREEN)"  
    echo "3. Refactor and improve (REFACTOR)"
    echo "4. Repeat cycle as needed"
    echo ""
    
    # Run initial tests to establish baseline
    tdd_quick_test
}

dev_commit_cycle() {
    local message="$1"
    
    step "Committing TDD cycle: $message"
    
    # Run tests before commit
    if ! tdd_quick_test; then
        error "Tests failing - fix before commit"
        return 1
    fi
    
    # Stage and commit changes
    git add -A
    git commit -m "$message

TDD Cycle: $(date)

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    
    log "✅ Changes committed successfully"
}

dev_integration_test() {
    log "Running integration test cycle"
    
    # Create snapshot if it doesn't exist
    if ! "$SCRIPT_DIR/test-runner.sh" snapshots | grep -q "test-baseline"; then
        warn "No test baseline found, creating one..."
        "$SCRIPT_DIR/test-runner.sh" baseline
    fi
    
    # Run full integration tests
    tdd_vm_test
}

# Performance testing
perf_test() {
    log "Running performance tests"
    
    # Test configuration build times
    step "Testing configuration build performance"
    for config in vm workstation server; do
        echo -n "Building $config... "
        local start_time=$(date +%s)
        if nix build --no-link --dry-run ".#nixosConfigurations.$config.config.system.build.toplevel" >/dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            echo -e "${GREEN}✅ ${duration}s${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
    
    # Test VM boot time if available
    if "$SCRIPT_DIR/test-runner.sh" vm-status | grep -q "running"; then
        step "Testing VM responsiveness"
        local start_time=$(date +%s)
        if ssh -o ConnectTimeout=30 nixos@10.10.10.180 "echo 'ready'" >/dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            echo -e "VM response time: ${GREEN}${duration}s${NC}"
        else
            echo -e "VM not responding: ${RED}❌${NC}"
        fi
    fi
}

# Main execution
main() {
    echo -e "${PURPLE}════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  TDD Workflow for NixOS Configuration${NC}"
    echo -e "${PURPLE}════════════════════════════════════════${NC}"
    echo ""
    
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        "red")
            tdd_red
            ;;
        "green")
            tdd_green
            ;;
        "refactor")
            tdd_refactor
            ;;
        "cycle")
            log "Running complete TDD cycle"
            tdd_red && tdd_green && tdd_refactor
            ;;
        "watch")
            tdd_watch
            ;;
        "quick")
            tdd_quick_test
            ;;
        "full")
            tdd_full_test
            ;;
        "vm")
            tdd_vm_test
            ;;
        "new")
            if [[ $# -eq 0 ]]; then
                error "Feature name required: $0 new <feature-name>"
                exit 1
            fi
            dev_new_feature "$1"
            ;;
        "commit")
            if [[ $# -eq 0 ]]; then
                error "Commit message required: $0 commit <message>"
                exit 1
            fi
            dev_commit_cycle "$*"
            ;;
        "integration")
            dev_integration_test
            ;;
        "perf")
            perf_test
            ;;
        "help"|*)
            echo "TDD Workflow Commands:"
            echo ""
            echo "TDD Cycle:"
            echo "  red         - Write failing tests (RED phase)"
            echo "  green       - Implement minimal solution (GREEN phase)"
            echo "  refactor    - Improve code quality (REFACTOR phase)"
            echo "  cycle       - Run complete RED-GREEN-REFACTOR cycle"
            echo ""
            echo "Testing:"
            echo "  quick       - Run quick tests (syntax + build)"
            echo "  full        - Run complete test suite"
            echo "  vm          - Run VM integration tests"
            echo "  watch       - Watch files and run tests automatically"
            echo ""
            echo "Development:"
            echo "  new <name>  - Start new feature development"
            echo "  commit <msg>- Commit with test validation"
            echo "  integration - Run integration test cycle"
            echo "  perf        - Run performance tests"
            echo ""
            echo "Examples:"
            echo "  $0 new media-streaming     # Start new feature"
            echo "  $0 watch                   # Auto-test on file changes"
            echo "  $0 cycle                   # Complete TDD cycle"
            echo "  $0 commit 'Add new module' # Commit with tests"
            ;;
    esac
}

main "$@"