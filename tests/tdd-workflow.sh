#!/usr/bin/env bash
# Simplified TDD Workflow for NixOS Configuration
# Automated test runner for continuous development

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Quick syntax and build test
quick_test() {
    log "Running quick validation..."
    "$SCRIPT_DIR/test-runner.sh" run syntax
    "$SCRIPT_DIR/test-runner.sh" run build
}

# Full test suite
full_test() {
    log "Running comprehensive test suite..."
    "$SCRIPT_DIR/test-runner.sh" run full
}

# Watch for file changes and auto-test
watch_files() {
    log "Watching for file changes... (Ctrl+C to stop)"
    
    if ! command -v inotifywait >/dev/null 2>&1; then
        error "inotifywait not found. Install inotify-tools to use watch mode."
        exit 1
    fi
    
    while true; do
        log "Waiting for changes in $ROOT_DIR..."
        
        # Watch for changes to .nix files
        inotifywait -r -e modify,create,delete --include='.*\.nix$' "$ROOT_DIR" 2>/dev/null
        
        log "Changes detected! Running tests..."
        quick_test
        
        echo ""
        log "Tests complete. Watching for more changes..."
        sleep 2
    done
}

# Test VM functionality
vm_test() {
    log "Testing VM functionality..."
    "$SCRIPT_DIR/test-runner.sh" vm-status
    "$SCRIPT_DIR/test-runner.sh" run integration
}

# Main function
main() {
    cd "$ROOT_DIR"
    
    local command="${1:-help}"
    
    case "$command" in
        "quick")
            quick_test
            ;;
        "full")
            full_test
            ;;
        "watch")
            watch_files
            ;;
        "vm")
            vm_test
            ;;
        "help"|*)
            echo "Simplified TDD Workflow"
            echo ""
            echo "Usage: $0 <command>"
            echo ""
            echo "Commands:"
            echo "  quick    - Run quick syntax and build tests"
            echo "  full     - Run comprehensive test suite"
            echo "  watch    - Watch files and auto-test on changes"
            echo "  vm       - Test VM functionality"
            echo ""
            echo "Examples:"
            echo "  $0 quick                    # Quick validation"
            echo "  $0 watch                    # Continuous testing"
            echo "  $0 full                     # All tests"
            ;;
    esac
}

main "$@"