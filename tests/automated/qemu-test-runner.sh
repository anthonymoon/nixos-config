#!/usr/bin/env bash
# QEMU-based test runner for NixOS configurations
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISO_PATH="${ISO_PATH:-$REPO_ROOT/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso}"

# Test configuration
VM_MEMORY="${VM_MEMORY:-4096}"
VM_DISK_SIZE="${VM_DISK_SIZE:-20G}"
SSH_PORT_BASE=2222
VNC_PORT_BASE=5900
MONITOR_PORT_BASE=55555

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
LOG_DIR="/tmp/nixos-qemu-tests"
mkdir -p "$LOG_DIR"

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*" | tee -a "$LOG_DIR/test.log"; }
success() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_DIR/test.log"; }
error() { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_DIR/test.log" >&2; }
warning() { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_DIR/test.log"; }
info() { echo -e "${CYAN}[i]${NC} $*" | tee -a "$LOG_DIR/test.log"; }
thought() { echo -e "${MAGENTA}[AGENT]${NC} $*" | tee -a "$LOG_DIR/agent.log"; }

# Check ISO exists
check_iso() {
    if [[ ! -f "$ISO_PATH" ]]; then
        error "ISO not found at: $ISO_PATH"
        error "Please build the ISO first with:"
        error "  sudo nix run --extra-experimental-features 'nix-command flakes' github:anthonymoon/nixos-config#build-iso"
        exit 1
    fi
    success "ISO found: $ISO_PATH"
}

# Create VM disk
create_disk() {
    local profile="$1"
    local disk_path="$LOG_DIR/nixos-${profile}.qcow2"
    
    log "Creating disk for $profile..."
    qemu-img create -f qcow2 "$disk_path" "$VM_DISK_SIZE"
    echo "$disk_path"
}

# Get VM ports
get_ports() {
    local index="$1"
    echo "$((SSH_PORT_BASE + index)) $((VNC_PORT_BASE + index)) $((MONITOR_PORT_BASE + index))"
}

# Start VM
start_vm() {
    local profile="$1"
    local disk_path="$2"
    local index="$3"
    read -r ssh_port vnc_port monitor_port <<< "$(get_ports "$index")"
    
    log "Starting VM for $profile (SSH: $ssh_port, VNC: :$vnc_port)"
    
    local qemu_cmd="qemu-system-x86_64 \
        -name nixos-test-$profile \
        -m $VM_MEMORY \
        -smp 2 \
        -enable-kvm \
        -cpu host \
        -drive file=$disk_path,if=virtio,format=qcow2 \
        -cdrom $ISO_PATH \
        -boot order=d \
        -netdev user,id=net0,hostfwd=tcp::${ssh_port}-:22 \
        -device virtio-net-pci,netdev=net0 \
        -monitor telnet:127.0.0.1:${monitor_port},server,nowait \
        -serial file:$LOG_DIR/${profile}-serial.log \
        -vnc :$((vnc_port - 5900)) \
        -daemonize \
        -pidfile $LOG_DIR/${profile}.pid"
    
    # Check if KVM is available
    if [[ ! -e /dev/kvm ]] || [[ ! -r /dev/kvm ]]; then
        warning "KVM not available, falling back to software emulation (slower)"
        qemu_cmd="${qemu_cmd//-enable-kvm/}"
        qemu_cmd="${qemu_cmd//-cpu host/-cpu qemu64}"
    fi
    
    eval "$qemu_cmd"
    
    if [[ -f "$LOG_DIR/${profile}.pid" ]]; then
        local pid=$(cat "$LOG_DIR/${profile}.pid")
        success "VM started with PID: $pid"
        return 0
    else
        error "Failed to start VM"
        return 1
    fi
}

# Wait for SSH
wait_for_ssh() {
    local port="$1"
    local max_wait=300  # 5 minutes
    local elapsed=0
    
    log "Waiting for SSH on port $port..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        if nc -z localhost "$port" 2>/dev/null; then
            # Try actual SSH connection
            if sshpass -p "nixos" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$port" nixos@localhost true 2>/dev/null; then
                success "SSH is ready!"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 5
        ((elapsed += 5))
    done
    
    error "SSH timeout after ${elapsed}s"
    return 1
}

# Monitor installation output
monitor_installation() {
    local profile="$1"
    local port="$2"
    
    thought "Starting installation monitoring for $profile"
    
    # Create install script on remote
    local install_script='
cd /tmp
curl -L https://raw.githubusercontent.com/anthonymoon/nixos-config/main/install/install.sh -o install.sh
chmod +x install.sh
export INSTALL_PROFILE='$profile'
export INSTALL_DISK=/dev/vda
export INSTALL_USER=testuser
export INSTALL_PASSWORD=testpass
echo "=== Starting installation for profile: '$profile' ==="
./install.sh 2>&1 | while IFS= read -r line; do
    echo "[$(date +%H:%M:%S)] $line"
done
echo "=== Installation completed with exit code: $? ==="
'
    
    # Run installation and capture output
    log "Running installation for $profile..."
    sshpass -p "nixos" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$port" nixos@localhost "$install_script" 2>&1 | \
    while IFS= read -r line; do
        echo "$line" | tee -a "$LOG_DIR/${profile}-install.log"
        
        # Pattern detection
        if [[ "$line" == *"error:"* ]] || [[ "$line" == *"ERROR"* ]]; then
            error "Error detected: $line"
            thought "Installation error detected, may need intervention"
        elif [[ "$line" == *"Setting up disk partitioning"* ]]; then
            thought "Critical phase: disk partitioning starting"
        elif [[ "$line" == *"Installing NixOS"* ]]; then
            thought "Main installation phase beginning"
        elif [[ "$line" == *"Installation complete"* ]]; then
            thought "Installation successful, preparing for reboot"
        fi
    done
    
    # Check if installation succeeded
    if tail -n 10 "$LOG_DIR/${profile}-install.log" | grep -q "completed with exit code: 0"; then
        success "Installation completed successfully for $profile"
        return 0
    else
        error "Installation failed for $profile"
        return 1
    fi
}

# Test profile
test_profile() {
    local profile="$1"
    local index="$2"
    
    log "============================================"
    log "Testing profile: $profile"
    log "============================================"
    
    # Create disk
    local disk_path=$(create_disk "$profile")
    
    # Start VM
    if ! start_vm "$profile" "$disk_path" "$index"; then
        error "Failed to start VM for $profile"
        return 1
    fi
    
    # Get ports
    read -r ssh_port vnc_port monitor_port <<< "$(get_ports "$index")"
    
    # Wait for boot
    if ! wait_for_ssh "$ssh_port"; then
        error "VM failed to boot for $profile"
        return 1
    fi
    
    # Run installation
    if monitor_installation "$profile" "$ssh_port"; then
        success "Profile $profile: Installation PASSED"
        echo "PASSED" > "$LOG_DIR/${profile}.result"
    else
        error "Profile $profile: Installation FAILED"
        echo "FAILED" > "$LOG_DIR/${profile}.result"
    fi
    
    # Stop VM
    if [[ -f "$LOG_DIR/${profile}.pid" ]]; then
        local pid=$(cat "$LOG_DIR/${profile}.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$LOG_DIR/${profile}.pid"
    fi
}

# Generate report
generate_report() {
    log "Generating test report..."
    
    {
        echo "NixOS QEMU Test Report"
        echo "====================="
        echo "Date: $(date)"
        echo "ISO: $ISO_PATH"
        echo ""
        echo "Results:"
        echo "--------"
        
        for profile in vm workstation server; do
            if [[ -f "$LOG_DIR/${profile}.result" ]]; then
                local result=$(cat "$LOG_DIR/${profile}.result")
                if [[ "$result" == "PASSED" ]]; then
                    echo "✅ $profile: PASSED"
                else
                    echo "❌ $profile: FAILED"
                fi
            else
                echo "⚪ $profile: NOT TESTED"
            fi
        done
        
        echo ""
        echo "Logs available in: $LOG_DIR"
        echo ""
        
        # Show any errors
        if grep -h "ERROR\|error:" "$LOG_DIR"/*.log 2>/dev/null | head -n 10; then
            echo ""
            echo "Recent errors (first 10):"
            echo "-------------------------"
            grep -h "ERROR\|error:" "$LOG_DIR"/*.log 2>/dev/null | head -n 10
        fi
    } | tee "$LOG_DIR/report.txt"
    
    success "Report saved to: $LOG_DIR/report.txt"
}

# Cleanup
cleanup() {
    log "Cleaning up..."
    
    # Stop all VMs
    for pidfile in "$LOG_DIR"/*.pid; do
        if [[ -f "$pidfile" ]]; then
            kill "$(cat "$pidfile")" 2>/dev/null || true
            rm -f "$pidfile"
        fi
    done
    
    # Remove disk images if requested
    if [[ "${CLEAN_DISKS:-no}" == "yes" ]]; then
        rm -f "$LOG_DIR"/*.qcow2
    fi
}

# Main
main() {
    local mode="${1:-test}"
    
    case "$mode" in
        test)
            check_iso
            cleanup
            
            # Test all profiles
            local profiles=("vm" "workstation" "server")
            local failed=0
            
            for i in "${!profiles[@]}"; do
                if ! test_profile "${profiles[$i]}" "$i"; then
                    ((failed++))
                fi
                echo
            done
            
            generate_report
            
            if [[ $failed -eq 0 ]]; then
                success "All tests passed!"
                exit 0
            else
                error "$failed tests failed!"
                exit 1
            fi
            ;;
            
        clean)
            cleanup
            rm -rf "$LOG_DIR"
            success "Cleanup complete"
            ;;
            
        *)
            cat << EOF
QEMU Test Runner for NixOS Configurations

Usage: $0 [test|clean]

Commands:
  test    Run tests for all profiles (default)
  clean   Clean up test artifacts

Environment variables:
  ISO_PATH       Path to NixOS ISO (default: repo ISO)
  VM_MEMORY      VM memory in MB (default: 4096)
  VM_DISK_SIZE   Disk size (default: 20G)
  CLEAN_DISKS    Remove disk images on cleanup (yes/no, default: no)

Logs are saved to: $LOG_DIR
EOF
            ;;
    esac
}

# Trap cleanup
trap cleanup EXIT

# Run
main "$@"