#!/usr/bin/env bash
# Automated VM Testing Framework for NixOS Configurations
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISO_PATH="${ISO_PATH:-$REPO_ROOT/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso}"
VM_NAME="nixos-test-vm"
VM_MEMORY="2048"
VM_DISK_SIZE="20G"
VM_DISK_PATH="/tmp/${VM_NAME}.qcow2"
SSH_PORT="2222"
VNC_PORT="5901"
MONITOR_SOCKET="/tmp/${VM_NAME}-monitor.sock"
SERIAL_LOG="/tmp/${VM_NAME}-serial.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }

# Cleanup function
cleanup() {
    log "Cleaning up..."
    if [[ -n "${QEMU_PID:-}" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
        log "Stopping VM..."
        echo "system_powerdown" | nc -U "$MONITOR_SOCKET" 2>/dev/null || true
        sleep 5
        kill "$QEMU_PID" 2>/dev/null || true
    fi
    rm -f "$VM_DISK_PATH" "$MONITOR_SOCKET" "$SERIAL_LOG"
}

trap cleanup EXIT

# Check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "qemu-img" "nc" "ssh" "sshpass")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        error "Install with: nix-env -iA nixpkgs.qemu nixpkgs.netcat nixpkgs.openssh nixpkgs.sshpass"
        exit 1
    fi
}

# Create VM disk
create_vm_disk() {
    log "Creating VM disk at $VM_DISK_PATH..."
    qemu-img create -f qcow2 "$VM_DISK_PATH" "$VM_DISK_SIZE"
    success "VM disk created"
}

# Start VM
start_vm() {
    log "Starting VM with ISO: $ISO_PATH"
    
    # Start QEMU in background
    qemu-system-x86_64 \
        -name "$VM_NAME" \
        -m "$VM_MEMORY" \
        -smp 2 \
        -enable-kvm \
        -cpu host \
        -drive file="$VM_DISK_PATH",if=virtio,format=qcow2 \
        -cdrom "$ISO_PATH" \
        -boot order=d \
        -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
        -device virtio-net-pci,netdev=net0 \
        -monitor unix:"$MONITOR_SOCKET",server,nowait \
        -serial file:"$SERIAL_LOG" \
        -vnc :1 \
        -daemonize \
        -pidfile "/tmp/${VM_NAME}.pid"
    
    QEMU_PID=$(cat "/tmp/${VM_NAME}.pid")
    success "VM started (PID: $QEMU_PID, VNC: :1, SSH: localhost:$SSH_PORT)"
}

# Wait for VM to boot
wait_for_boot() {
    log "Waiting for VM to boot..."
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if nc -z localhost "$SSH_PORT" 2>/dev/null; then
            success "VM is accessible via SSH"
            return 0
        fi
        echo -n "."
        sleep 5
        ((attempt++))
    done
    
    error "VM failed to boot within timeout"
    return 1
}

# SSH into VM
ssh_vm() {
    local cmd="${1:-}"
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $SSH_PORT"
    
    if [[ -z "$cmd" ]]; then
        sshpass -p "nixos" ssh $ssh_opts root@localhost
    else
        sshpass -p "nixos" ssh $ssh_opts root@localhost "$cmd"
    fi
}

# Run installation test
test_installation() {
    local profile="$1"
    log "Testing installation of profile: $profile"
    
    # Copy install script to VM
    log "Preparing installation..."
    ssh_vm "curl -L https://raw.githubusercontent.com/anthonymoon/nixos-config/main/install/install.sh -o /tmp/install.sh && chmod +x /tmp/install.sh"
    
    # Run installation
    log "Running installation for profile: $profile"
    if ssh_vm "INSTALL_PROFILE=$profile INSTALL_DISK=/dev/vda INSTALL_USER=testuser /tmp/install.sh"; then
        success "Installation completed successfully"
        return 0
    else
        error "Installation failed"
        return 1
    fi
}

# Run profile tests
test_profile() {
    local profile="$1"
    log "Running tests for profile: $profile"
    
    case "$profile" in
        vm)
            # Test VM-specific features
            ssh_vm "systemctl is-active qemu-guest-agent" && success "QEMU guest agent active" || error "QEMU guest agent not active"
            ssh_vm "test -d /run/current-system" && success "NixOS system detected" || error "NixOS system not detected"
            ;;
        workstation)
            # Test workstation features
            ssh_vm "systemctl is-active display-manager" && success "Display manager active" || error "Display manager not active"
            ssh_vm "command -v steam" && success "Steam installed" || error "Steam not found"
            ;;
        server)
            # Test server features
            ssh_vm "systemctl is-active fail2ban" && success "Fail2ban active" || error "Fail2ban not active"
            ssh_vm "systemctl is-active docker" && success "Docker active" || error "Docker not active"
            ;;
    esac
}

# Main test runner
run_tests() {
    local profile="${1:-all}"
    local profiles=()
    
    if [[ "$profile" == "all" ]]; then
        profiles=("vm" "workstation" "server")
    else
        profiles=("$profile")
    fi
    
    for p in "${profiles[@]}"; do
        log "=== Testing profile: $p ==="
        
        # Clean previous state
        cleanup
        
        # Create and start VM
        create_vm_disk
        start_vm
        wait_for_boot
        
        # Run tests
        if test_installation "$p"; then
            # Reboot into installed system
            log "Rebooting into installed system..."
            ssh_vm "reboot" || true
            sleep 10
            wait_for_boot
            
            # Run profile-specific tests
            test_profile "$p"
        fi
        
        log "=== Completed testing profile: $p ==="
        echo
    done
}

# Command line interface
main() {
    case "${1:-help}" in
        test)
            check_dependencies
            run_tests "${2:-all}"
            ;;
        start)
            check_dependencies
            create_vm_disk
            start_vm
            wait_for_boot
            log "VM is ready. SSH: ssh -p $SSH_PORT root@localhost (password: nixos)"
            log "VNC: vncviewer localhost:$VNC_PORT"
            ;;
        stop)
            cleanup
            ;;
        ssh)
            ssh_vm "${2:-}"
            ;;
        monitor)
            if [[ -S "$MONITOR_SOCKET" ]]; then
                nc -U "$MONITOR_SOCKET"
            else
                error "Monitor socket not found. Is the VM running?"
            fi
            ;;
        log)
            if [[ -f "$SERIAL_LOG" ]]; then
                tail -f "$SERIAL_LOG"
            else
                error "Serial log not found. Is the VM running?"
            fi
            ;;
        help|*)
            cat << EOF
NixOS VM Testing Framework

Usage: $0 <command> [options]

Commands:
  test [profile]    Run automated tests (profile: vm|workstation|server|all)
  start            Start a VM with the ISO for manual testing
  stop             Stop the VM and cleanup
  ssh [command]    SSH into the running VM
  monitor          Connect to QEMU monitor
  log              View serial console log
  help             Show this help message

Examples:
  $0 test vm       # Test only VM profile
  $0 test all      # Test all profiles
  $0 start         # Start VM for manual testing
  $0 ssh           # SSH into running VM
  $0 ssh "systemctl status"  # Run command in VM

Environment Variables:
  ISO_PATH         Path to NixOS ISO (default: repo ISO)
  VM_MEMORY        VM memory in MB (default: 2048)
  VM_DISK_SIZE     VM disk size (default: 20G)
EOF
            ;;
    esac
}

main "$@"