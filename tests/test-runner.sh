#!/usr/bin/env bash
# NixOS Configuration Test Runner
# Automated testing with VM snapshot/restore capabilities

set -euo pipefail

# Configuration
TEST_VM_NAME="${TEST_VM_NAME:-nixos-25.05}"
TEST_VM_IP="${TEST_VM_IP:-10.10.10.180}"
TEST_VM_USER="${TEST_VM_USER:-nixos}"
TEST_SNAPSHOT_NAME="test-baseline"
TEST_TIMEOUT=300
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

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

test_start() {
    echo -e "${BLUE}[TEST]${NC} $1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# VM Management Functions
vm_exists() {
    sudo virsh list --all --name | grep -q "^${TEST_VM_NAME}$"
}

vm_running() {
    sudo virsh list --name | grep -q "^${TEST_VM_NAME}$"
}

vm_start() {
    if ! vm_running; then
        log "Starting VM: $TEST_VM_NAME"
        sudo virsh start "$TEST_VM_NAME" >/dev/null
        sleep 10
        wait_for_vm
    fi
}

vm_stop() {
    if vm_running; then
        log "Stopping VM: $TEST_VM_NAME"
        sudo virsh shutdown "$TEST_VM_NAME" >/dev/null
        sleep 5
    fi
}

vm_force_stop() {
    if vm_running; then
        log "Force stopping VM: $TEST_VM_NAME"
        sudo virsh destroy "$TEST_VM_NAME" >/dev/null
        sleep 2
    fi
}

vm_create_snapshot() {
    local name="$1"
    log "Creating VM snapshot: $name"
    vm_stop
    sudo virsh snapshot-create-as "$TEST_VM_NAME" "$name" "Test baseline snapshot" >/dev/null
}

vm_restore_snapshot() {
    local name="$1"
    log "Restoring VM from snapshot: $name"
    vm_force_stop
    sudo virsh snapshot-revert "$TEST_VM_NAME" "$name" >/dev/null
    vm_start
}

vm_list_snapshots() {
    sudo virsh snapshot-list "$TEST_VM_NAME" --name
}

vm_delete_snapshot() {
    local name="$1"
    if sudo virsh snapshot-list "$TEST_VM_NAME" --name | grep -q "^${name}$"; then
        log "Deleting snapshot: $name"
        sudo virsh snapshot-delete "$TEST_VM_NAME" "$name" >/dev/null
    fi
}

wait_for_vm() {
    log "Waiting for VM to be ready..."
    local count=0
    while [ $count -lt $TEST_TIMEOUT ]; do
        if ping -c 1 -W 2 "$TEST_VM_IP" >/dev/null 2>&1; then
            if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$TEST_VM_USER@$TEST_VM_IP" "echo ready" >/dev/null 2>&1; then
                log "VM is ready"
                return 0
            fi
        fi
        sleep 2
        count=$((count + 2))
    done
    error "VM failed to become ready within $TEST_TIMEOUT seconds"
    return 1
}

vm_exec() {
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$TEST_VM_USER@$TEST_VM_IP" "$@"
}

vm_copy() {
    scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$1" "$TEST_VM_USER@$TEST_VM_IP:$2"
}

# Test Functions
test_syntax_validation() {
    test_start "Syntax validation for all Nix files"
    
    local failed=0
    for file in "$ROOT_DIR"/{flake.nix,profiles/*.nix,modules/*.nix}; do
        if [[ -f "$file" ]]; then
            if ! nix-instantiate --parse "$file" >/dev/null 2>&1; then
                test_fail "Syntax error in $(basename "$file")"
                failed=1
            fi
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        test_pass "All Nix files have valid syntax"
    fi
}

test_flake_evaluation() {
    test_start "Flake evaluation and configuration building"
    
    cd "$ROOT_DIR"
    
    # Clear Nix evaluation cache to ensure fresh builds (user and root)
    log "Clearing Nix evaluation cache..."
    rm -rf ~/.cache/nix/eval-cache-v* 2>/dev/null || true
    sudo rm -rf /root/.cache/nix/eval-cache-v* 2>/dev/null || true
    
    # Test each configuration builds with refresh flag
    for config in vm workstation server; do
        if sudo nix --refresh --extra-experimental-features "nix-command flakes" build --no-link --dry-run --no-write-lock-file ".#nixosConfigurations.$config.config.system.build.toplevel" >/dev/null 2>&1; then
            test_pass "Configuration '$config' builds successfully"
        else
            test_fail "Configuration '$config' failed to build"
        fi
    done
}

test_vm_installation() {
    test_start "VM installation test"
    
    if ! vm_exists; then
        test_skip "VM '$TEST_VM_NAME' does not exist"
        return
    fi
    
    # Restore to clean state
    if sudo virsh snapshot-list "$TEST_VM_NAME" --name | grep -q "^${TEST_SNAPSHOT_NAME}$"; then
        vm_restore_snapshot "$TEST_SNAPSHOT_NAME"
    else
        vm_start
    fi
    
    # Test basic connectivity
    if ! wait_for_vm; then
        test_fail "VM connectivity test failed"
        return
    fi
    
    # Clear cache and test installation command with latest commit (user and root)
    vm_exec "rm -rf ~/.cache/nix/eval-cache-v* 2>/dev/null || true" >/dev/null 2>&1
    vm_exec "sudo rm -rf /root/.cache/nix/eval-cache-v* 2>/dev/null || true" >/dev/null 2>&1
    
    # Get latest commit hash for explicit reference
    local commit_hash=$(git rev-parse HEAD)
    
    # Test installation command with explicit commit hash and refresh
    if vm_exec "nix run --refresh --extra-experimental-features 'nix-command flakes' --no-write-lock-file github:anthonymoon/nixos-config/$commit_hash#post-install vm" >/dev/null 2>&1; then
        test_pass "VM installation/post-install completed successfully"
    else
        test_fail "VM installation/post-install failed"
    fi
}

test_module_functionality() {
    test_start "Module functionality tests"
    
    if ! vm_running || ! wait_for_vm; then
        test_skip "VM not available for module testing"
        return
    fi
    
    # Test basic system info
    if vm_exec "nixos-version" >/dev/null 2>&1; then
        test_pass "NixOS system responsive"
    else
        test_fail "NixOS system not responsive"
    fi
    
    # Test user creation
    if vm_exec "id amoon" >/dev/null 2>&1; then
        test_pass "User 'amoon' exists"
    else
        test_fail "User 'amoon' not found"
    fi
    
    # Test sudo access
    if vm_exec "sudo echo 'sudo works'" >/dev/null 2>&1; then
        test_pass "Sudo access working"
    else
        test_fail "Sudo access not working"
    fi
}

test_security_configuration() {
    test_start "Security configuration validation"
    
    if ! vm_running || ! wait_for_vm; then
        test_skip "VM not available for security testing"
        return
    fi
    
    # Test SSH configuration
    if vm_exec "sudo sshd -t" >/dev/null 2>&1; then
        test_pass "SSH configuration valid"
    else
        test_fail "SSH configuration invalid"
    fi
    
    # Test firewall status
    if vm_exec "sudo systemctl is-active iptables" >/dev/null 2>&1 || vm_exec "sudo iptables -L" >/dev/null 2>&1; then
        test_pass "Firewall is active"
    else
        test_fail "Firewall not properly configured"
    fi
}

test_performance_validation() {
    test_start "Performance and resource validation"
    
    if ! vm_running || ! wait_for_vm; then
        test_skip "VM not available for performance testing"
        return
    fi
    
    # Test system resources
    local memory_usage
    memory_usage=$(vm_exec "free | awk '/^Mem:/ {print int(\$3/\$2*100)}'")
    
    if [[ $memory_usage -lt 80 ]]; then
        test_pass "Memory usage acceptable: ${memory_usage}%"
    else
        test_fail "Memory usage too high: ${memory_usage}%"
    fi
    
    # Test disk space
    local disk_usage
    disk_usage=$(vm_exec "df / | awk 'NR==2 {print \$5}' | sed 's/%//'")
    
    if [[ $disk_usage -lt 90 ]]; then
        test_pass "Disk usage acceptable: ${disk_usage}%"
    else
        test_fail "Disk usage too high: ${disk_usage}%"
    fi
}

# Test execution control
run_test_suite() {
    local suite="$1"
    
    case "$suite" in
        "syntax")
            test_syntax_validation
            ;;
        "build")
            test_flake_evaluation
            ;;
        "install")
            test_vm_installation
            ;;
        "integration")
            test_module_functionality
            test_security_configuration
            test_performance_validation
            ;;
        "full")
            test_syntax_validation
            test_flake_evaluation
            test_vm_installation
            test_module_functionality
            test_security_configuration
            test_performance_validation
            ;;
        *)
            error "Unknown test suite: $suite"
            echo "Available suites: syntax, build, install, integration, full"
            exit 1
            ;;
    esac
}

# Snapshot management
create_baseline() {
    log "Creating test baseline snapshot"
    if ! vm_exists; then
        error "VM '$TEST_VM_NAME' does not exist"
        exit 1
    fi
    
    vm_delete_snapshot "$TEST_SNAPSHOT_NAME"
    vm_create_snapshot "$TEST_SNAPSHOT_NAME"
    log "Baseline snapshot '$TEST_SNAPSHOT_NAME' created"
}

# Main execution
main() {
    echo -e "${PURPLE}════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  NixOS Configuration Test Runner${NC}"
    echo -e "${PURPLE}════════════════════════════════════════${NC}"
    echo ""
    
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        "run")
            local suite="${1:-full}"
            log "Running test suite: $suite"
            run_test_suite "$suite"
            ;;
        "baseline")
            create_baseline
            ;;
        "vm-start")
            vm_start
            ;;
        "vm-stop")
            vm_stop
            ;;
        "vm-restore")
            vm_restore_snapshot "$TEST_SNAPSHOT_NAME"
            ;;
        "vm-status")
            if vm_exists; then
                if vm_running; then
                    echo "VM '$TEST_VM_NAME' is running"
                    if wait_for_vm 2>/dev/null; then
                        echo "VM is accessible via SSH"
                    else
                        echo "VM is not accessible via SSH"
                    fi
                else
                    echo "VM '$TEST_VM_NAME' is stopped"
                fi
            else
                echo "VM '$TEST_VM_NAME' does not exist"
            fi
            ;;
        "snapshots")
            echo "Available snapshots for '$TEST_VM_NAME':"
            vm_list_snapshots
            ;;
        "help"|*)
            echo "NixOS Configuration Test Runner"
            echo ""
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Test Commands:"
            echo "  run [suite]     - Run test suite (syntax|build|install|integration|full)"
            echo "  baseline        - Create baseline snapshot for testing"
            echo ""
            echo "VM Management:"
            echo "  vm-start        - Start the test VM"
            echo "  vm-stop         - Stop the test VM"
            echo "  vm-restore      - Restore VM to baseline snapshot"
            echo "  vm-status       - Check VM status"
            echo "  snapshots       - List available snapshots"
            echo ""
            echo "Examples:"
            echo "  $0 baseline                 # Create test baseline"
            echo "  $0 run syntax              # Run syntax tests only"
            echo "  $0 run full                # Run all tests"
            echo "  $0 vm-restore && $0 run install  # Fresh install test"
            ;;
    esac
    
    # Print test summary if tests were run
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        echo ""
        echo -e "${PURPLE}════════════════════════════════════════${NC}"
        echo -e "${PURPLE}  Test Summary${NC}"
        echo -e "${PURPLE}════════════════════════════════════════${NC}"
        echo "Total tests: $TESTS_TOTAL"
        echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
        echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
        
        if [[ $TESTS_FAILED -eq 0 ]]; then
            echo -e "${GREEN}All tests passed! ✅${NC}"
            exit 0
        else
            echo -e "${RED}Some tests failed! ❌${NC}"
            exit 1
        fi
    fi
}

# Execute main function with all arguments
main "$@"