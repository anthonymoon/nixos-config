#!/usr/bin/env bash
# Streaming Test Runner - Real-time monitoring and reaction system
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISO_PATH="${ISO_PATH:-$REPO_ROOT/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso}"
VM_NAME="nixos-test-vm"
VM_MEMORY="4096"
VM_CPUS="2"
VM_DISK_SIZE="20G"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"

# State tracking
STATE_FILE="/tmp/nixos-test-state.json"
LOG_DIR="/tmp/nixos-test-logs"
STREAM_FIFO="/tmp/nixos-test-stream.fifo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize logging
mkdir -p "$LOG_DIR"
mkfifo "$STREAM_FIFO" 2>/dev/null || true

# Logging functions with timestamps
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_DIR/main.log"; }
success() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_DIR/main.log"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2 | tee -a "$LOG_DIR/main.log"; }
warning() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_DIR/main.log"; }
thought() { echo -e "${MAGENTA}[AGENT THOUGHT]${NC} $*" | tee -a "$LOG_DIR/agent-thoughts.log"; }
stream() { echo -e "${CYAN}[STREAM]${NC} $*" | tee -a "$LOG_DIR/stream.log"; }

# State management
save_state() {
    local key="$1"
    local value="$2"
    if [[ -f "$STATE_FILE" ]]; then
        jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    else
        echo "{\"$key\": \"$value\"}" > "$STATE_FILE"
    fi
}

get_state() {
    local key="$1"
    [[ -f "$STATE_FILE" ]] && jq -r ".$key // empty" "$STATE_FILE"
}

# VM Management
create_vm() {
    local profile="$1"
    log "Creating VM for profile: $profile"
    
    # Check if VM exists
    if virsh --connect "$LIBVIRT_URI" list --all | grep -q "$VM_NAME"; then
        log "VM already exists, destroying it first..."
        virsh --connect "$LIBVIRT_URI" destroy "$VM_NAME" 2>/dev/null || true
        virsh --connect "$LIBVIRT_URI" undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true
    fi
    
    # Create VM disk
    local disk_path="/var/lib/libvirt/images/${VM_NAME}.qcow2"
    qemu-img create -f qcow2 "$disk_path" "$VM_DISK_SIZE"
    
    # Create VM
    virt-install \
        --connect "$LIBVIRT_URI" \
        --name "$VM_NAME" \
        --memory "$VM_MEMORY" \
        --vcpus "$VM_CPUS" \
        --disk path="$disk_path",format=qcow2,bus=virtio \
        --cdrom "$ISO_PATH" \
        --network network=default,model=virtio \
        --graphics vnc,listen=0.0.0.0 \
        --noautoconsole \
        --os-variant nixos-unstable \
        --boot uefi
    
    # Create snapshot
    log "Creating clean snapshot..."
    virsh --connect "$LIBVIRT_URI" snapshot-create-as "$VM_NAME" clean-installer-state "Clean installer state"
    
    save_state "vm_name" "$VM_NAME"
    save_state "current_profile" "$profile"
    success "VM created with clean snapshot"
}

# Network discovery
discover_vm_ip() {
    log "Discovering VM IP address..."
    local max_attempts=30
    local attempt=0
    local ip=""
    
    while [[ $attempt -lt $max_attempts ]]; do
        ip=$(virsh --connect "$LIBVIRT_URI" net-dhcp-leases default | grep "$VM_NAME" | awk '{print $5}' | cut -d'/' -f1 | head -n1)
        if [[ -n "$ip" ]]; then
            save_state "vm_ip" "$ip"
            success "VM IP discovered: $ip"
            return 0
        fi
        sleep 2
        ((attempt++))
    done
    
    error "Failed to discover VM IP"
    return 1
}

# SSH utilities
wait_for_ssh() {
    local ip="$1"
    log "Waiting for SSH on $ip..."
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "nixos@$ip" true 2>/dev/null; then
            success "SSH is ready"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    error "SSH timeout"
    return 1
}

# Stream processor - runs in background
process_stream() {
    local profile="$1"
    local phase="$2"
    local critical_errors=(
        "error: Disko partitioning failed"
        "error: Failed to mount"
        "Installation failed"
        "CRITICAL ERROR"
        "kernel panic"
        "out of memory"
    )
    
    while IFS= read -r line; do
        stream "$line"
        
        # Check for critical errors
        for error_pattern in "${critical_errors[@]}"; do
            if [[ "$line" == *"$error_pattern"* ]]; then
                thought "CRITICAL FAILURE DETECTED: $error_pattern"
                error "Installation failed for $profile during $phase"
                save_state "last_error" "$error_pattern"
                save_state "test_status_$profile" "failed"
                echo "FAIL" > "$LOG_DIR/${profile}_${phase}.status"
                return 1
            fi
        done
        
        # Pattern matching for different phases
        case "$phase" in
            installation)
                if [[ "$line" == *"Setting up disk partitioning"* ]]; then
                    thought "Disko partitioning starting - critical phase"
                elif [[ "$line" == *"Installing NixOS configuration"* ]]; then
                    thought "NixOS installation beginning"
                elif [[ "$line" == *"Installation complete"* ]]; then
                    thought "Installation successful, preparing for reboot"
                    echo "SUCCESS" > "$LOG_DIR/${profile}_${phase}.status"
                fi
                ;;
            testing)
                if [[ "$line" == *"starting VM..."* ]]; then
                    thought "NixOS test framework starting VM"
                elif [[ "$line" == *"test script finished with exit code 0"* ]]; then
                    thought "Test completed successfully"
                    echo "SUCCESS" > "$LOG_DIR/${profile}_${phase}.status"
                elif [[ "$line" == *"test script finished with exit code"* ]]; then
                    thought "Test failed with non-zero exit code"
                    echo "FAIL" > "$LOG_DIR/${profile}_${phase}.status"
                fi
                ;;
        esac
    done
}

# Run installation with streaming
run_installation() {
    local profile="$1"
    local ip=$(get_state "vm_ip")
    
    log "Starting installation for profile: $profile"
    
    # Copy repository to VM
    log "Copying repository to VM..."
    scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$REPO_ROOT"/* "nixos@$ip:/tmp/nixos-config/"
    
    # Create installation command
    local install_cmd="sudo INSTALL_PROFILE=$profile INSTALL_DISK=/dev/vda INSTALL_USER=testuser /tmp/nixos-config/install/install.sh"
    
    # Run installation with streaming
    thought "Initiating installation and monitoring output stream"
    
    # Start stream processor in background
    process_stream "$profile" "installation" < "$STREAM_FIFO" &
    local processor_pid=$!
    
    # Execute installation and pipe to processor
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "nixos@$ip" \
        "script -q -c '$install_cmd' /tmp/install.log" 2>&1 | tee "$STREAM_FIFO" > "$LOG_DIR/${profile}_install.log"
    
    # Wait for processor to finish
    wait $processor_pid
    local status=$?
    
    # Check final status
    if [[ -f "$LOG_DIR/${profile}_installation.status" ]] && [[ $(cat "$LOG_DIR/${profile}_installation.status") == "SUCCESS" ]]; then
        success "Installation completed for $profile"
        return 0
    else
        error "Installation failed for $profile"
        return 1
    fi
}

# Run post-installation tests
run_tests() {
    local profile="$1"
    local ip=$(get_state "vm_ip")
    
    log "Waiting for system reboot..."
    sleep 30
    wait_for_ssh "$ip"
    
    log "Running declarative tests for profile: $profile"
    
    # Start stream processor
    process_stream "$profile" "testing" < "$STREAM_FIFO" &
    local processor_pid=$!
    
    # Run tests
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "testuser@$ip" \
        "cd /etc/nixos && sudo nix flake check .#${profile}-test" 2>&1 | tee "$STREAM_FIFO" > "$LOG_DIR/${profile}_test.log"
    
    wait $processor_pid
    
    if [[ -f "$LOG_DIR/${profile}_testing.status" ]] && [[ $(cat "$LOG_DIR/${profile}_testing.status") == "SUCCESS" ]]; then
        success "✅ $profile profile installed and passed all tests"
        save_state "test_status_$profile" "passed"
        return 0
    else
        error "❌ $profile profile tests failed"
        save_state "test_status_$profile" "failed"
        return 1
    fi
}

# Test a single profile
test_profile() {
    local profile="$1"
    
    log "=== Testing Profile: $profile ==="
    thought "Beginning test sequence for $profile profile"
    
    # Create/revert VM
    if virsh --connect "$LIBVIRT_URI" snapshot-list "$VM_NAME" 2>/dev/null | grep -q clean-installer-state; then
        log "Reverting to clean snapshot..."
        virsh --connect "$LIBVIRT_URI" snapshot-revert "$VM_NAME" clean-installer-state
    else
        create_vm "$profile"
    fi
    
    # Start VM
    virsh --connect "$LIBVIRT_URI" start "$VM_NAME"
    
    # Discover IP
    if ! discover_vm_ip; then
        error "Failed to discover VM IP for $profile"
        return 1
    fi
    
    # Wait for SSH
    local ip=$(get_state "vm_ip")
    if ! wait_for_ssh "$ip"; then
        error "VM failed to become accessible for $profile"
        return 1
    fi
    
    # Run installation
    if run_installation "$profile"; then
        # Run tests after reboot
        run_tests "$profile"
    fi
    
    # Stop VM
    virsh --connect "$LIBVIRT_URI" destroy "$VM_NAME" 2>/dev/null || true
    
    log "=== Completed Testing Profile: $profile ==="
}

# Main test orchestrator
run_all_tests() {
    local profiles=("vm" "workstation" "server")
    local failed=0
    
    log "Starting automated test suite for all profiles"
    rm -f "$STATE_FILE"
    
    for profile in "${profiles[@]}"; do
        if ! test_profile "$profile"; then
            ((failed++))
        fi
        echo
    done
    
    # Summary
    log "===== TEST SUMMARY ====="
    for profile in "${profiles[@]}"; do
        local status=$(get_state "test_status_$profile")
        if [[ "$status" == "passed" ]]; then
            success "$profile: PASSED"
        else
            error "$profile: FAILED"
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        success "All tests passed!"
        return 0
    else
        error "$failed profiles failed testing"
        return 1
    fi
}

# Main
main() {
    case "${1:-help}" in
        test)
            if [[ "${2:-}" == "all" ]] || [[ -z "${2:-}" ]]; then
                run_all_tests
            else
                test_profile "$2"
            fi
            ;;
        clean)
            log "Cleaning up test environment..."
            virsh --connect "$LIBVIRT_URI" destroy "$VM_NAME" 2>/dev/null || true
            virsh --connect "$LIBVIRT_URI" undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true
            rm -rf "$LOG_DIR" "$STATE_FILE" "$STREAM_FIFO"
            success "Cleanup complete"
            ;;
        logs)
            if [[ -d "$LOG_DIR" ]]; then
                ls -la "$LOG_DIR"
            else
                error "No logs found"
            fi
            ;;
        help|*)
            cat << EOF
NixOS Streaming Test Runner

Usage: $0 <command> [options]

Commands:
  test [profile|all]  Run automated tests with real-time monitoring
  clean              Clean up all test artifacts
  logs               Show available logs
  help               Show this help message

Examples:
  $0 test vm         # Test only VM profile
  $0 test all        # Test all profiles  
  $0 clean           # Clean up everything

Logs are stored in: $LOG_DIR
State is tracked in: $STATE_FILE
EOF
            ;;
    esac
}

main "$@"