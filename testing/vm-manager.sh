#!/usr/bin/env bash
# VM Management Infrastructure for Agent-Based Testing
# Provides pristine, controlled test environments for each NixOS profile

set -euo pipefail

# Configuration
VM_NAME="nixos-test-vm"
VM_MEMORY="4096"
VM_DISK_SIZE="20G"
VM_BRIDGE="virbr0"
BASE_SNAPSHOT="clean-installer-state"
NIXOS_ISO_PATH="$HOME/latest-nixos-graphical-x86_64-linux.iso"
WORK_DIR="/tmp/nixos-testing"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[VM-MGR]${NC} $1"; }
warn() { echo -e "${YELLOW}[VM-MGR]${NC} $1"; }
error() { echo -e "${RED}[VM-MGR]${NC} $1"; exit 1; }

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v virsh >/dev/null || error "virsh not found. Install libvirt."
    command -v virt-install >/dev/null || error "virt-install not found. Install virt-install."
    command -v qemu-img >/dev/null || error "qemu-img not found. Install qemu-utils."
    
    # Check if libvirt is running
    if ! systemctl is-active --quiet libvirtd; then
        warn "libvirtd not running. Starting..."
        sudo systemctl start libvirtd
    fi
    
    # Check if user is in libvirt group
    if ! groups | grep -q libvirt; then
        warn "User not in libvirt group. You may need to add yourself: sudo usermod -a -G libvirt \$USER"
    fi
    
    mkdir -p "$WORK_DIR"
    log "Prerequisites checked ✓"
}

# Use existing NixOS ISO from home directory
ensure_iso() {
    if [[ ! -f "$NIXOS_ISO_PATH" ]]; then
        error "NixOS ISO not found at $NIXOS_ISO_PATH"
    fi
    
    log "Using existing ISO: $NIXOS_ISO_PATH"
    # Return ISO path without any log output that could interfere
    printf "%s" "$NIXOS_ISO_PATH"
}

# Create base VM if it doesn't exist
create_base_vm() {
    local iso_path="$1"
    
    if virsh list --all | grep -q "$VM_NAME"; then
        log "VM $VM_NAME already exists"
        return
    fi
    
    log "Creating base VM: $VM_NAME"
    
    # Create disk image
    qemu-img create -f qcow2 "$WORK_DIR/${VM_NAME}.qcow2" "$VM_DISK_SIZE"
    
    # Create VM
    virt-install \
        --name "$VM_NAME" \
        --memory "$VM_MEMORY" \
        --vcpus 2 \
        --disk path="$WORK_DIR/${VM_NAME}.qcow2,format=qcow2" \
        --cdrom "$iso_path" \
        --network bridge="$VM_BRIDGE" \
        --graphics vnc,listen=127.0.0.1 \
        --noautoconsole \
        --boot cdrom,hd
    
    log "Base VM created ✓"
}

# Wait for VM to get IP address
wait_for_ip() {
    local timeout=300
    local elapsed=0
    
    log "Waiting for VM to get IP address on 10.10.10.0/23..."
    
    while [[ $elapsed -lt $timeout ]]; do
        local ip=$(get_vm_ip)
        if [[ -n "$ip" && "$ip" =~ ^10\.10\.(10|11)\.[0-9]+$ ]]; then
            log "VM IP: $ip"
            echo "$ip"
            return
        fi
        
        # Show progress every 30 seconds
        if [[ $((elapsed % 30)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            log "Still waiting for IP... (${elapsed}s elapsed)"
            # Debug: show what we found
            virsh domifaddr "$VM_NAME" 2>/dev/null || true
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    error "Timeout waiting for VM IP after ${timeout}s"
}

# Get VM IP address from virsh domifaddr or arp table
get_vm_ip() {
    # Try virsh domifaddr first (works with guest agent)
    local ip=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -E '10\.10\.(10|11)\.' | awk '{print $4}' | cut -d'/' -f1 | head -1)
    
    # If that doesn't work, try virsh domifaddr with --source lease
    if [[ -z "$ip" ]]; then
        ip=$(virsh domifaddr "$VM_NAME" --source lease 2>/dev/null | grep -E '10\.10\.(10|11)\.' | awk '{print $4}' | cut -d'/' -f1 | head -1)
    fi
    
    # Try virsh domifaddr with --source arp
    if [[ -z "$ip" ]]; then
        ip=$(virsh domifaddr "$VM_NAME" --source arp 2>/dev/null | grep -E '10\.10\.(10|11)\.' | awk '{print $4}' | cut -d'/' -f1 | head -1)
    fi
    
    # If that doesn't work, try to find it via MAC address and arp
    if [[ -z "$ip" ]]; then
        local mac=$(virsh domiflist "$VM_NAME" 2>/dev/null | grep "$VM_BRIDGE" | awk '{print $5}' | head -1)
        if [[ -n "$mac" ]]; then
            # Force ARP refresh
            ping -c 1 -W 1 10.10.10.255 >/dev/null 2>&1 || true
            ip=$(arp -n | grep -i "$mac" | grep -E '10\.10\.(10|11)\.' | awk '{print $1}' | head -1)
        fi
    fi
    
    echo "$ip"
}

# Wait for SSH to be available
wait_for_ssh() {
    local ip="$1"
    local user="${2:-nixos}"
    local timeout=300
    local elapsed=0
    
    log "Waiting for SSH on $ip (user: $user)..."
    
    while [[ $elapsed -lt $timeout ]]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
               "$user@$ip" "echo 'SSH ready'" >/dev/null 2>&1; then
            log "SSH ready ✓"
            return
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    error "Timeout waiting for SSH on $ip"
}

# Create clean installer snapshot
create_base_snapshot() {
    log "Creating base snapshot: $BASE_SNAPSHOT"
    
    # Start VM and wait for it to boot to installer
    virsh start "$VM_NAME" || warn "VM may already be running"
    local ip=$(wait_for_ip)
    wait_for_ssh "$ip" "nixos"
    
    # Ensure we're in a clean installer state
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@"$ip" \
        "lsblk && echo 'Installer ready for snapshot'"
    
    # Shutdown and create snapshot
    log "Shutting down VM for snapshot..."
    virsh shutdown "$VM_NAME"
    
    # Wait for shutdown
    while virsh list --state-running | grep -q "$VM_NAME"; do
        sleep 2
    done
    
    # Create snapshot
    virsh snapshot-create-as "$VM_NAME" "$BASE_SNAPSHOT" \
        "Clean NixOS installer state - ready for testing"
    
    log "Base snapshot created ✓"
}

# Revert to clean state
revert_to_clean() {
    log "Reverting VM to clean installer state..."
    
    # Ensure VM is stopped
    if virsh list --state-running | grep -q "$VM_NAME"; then
        virsh destroy "$VM_NAME"
    fi
    
    # Revert to snapshot
    virsh snapshot-revert "$VM_NAME" "$BASE_SNAPSHOT"
    
    log "VM reverted to clean state ✓"
}

# Start VM and return IP
start_vm() {
    log "Starting VM..."
    
    virsh start "$VM_NAME"
    local ip=$(wait_for_ip)
    wait_for_ssh "$ip" "nixos"
    
    echo "$ip"
}

# Copy nixos-config to VM
deploy_config() {
    local ip="$1"
    local config_path="${2:-/home/amoon/nixos-config}"
    
    log "Deploying nixos-config to VM at $ip..."
    
    # Create temp directory on VM
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@"$ip" \
        "sudo mkdir -p /tmp/nixos-config && sudo chown nixos:users /tmp/nixos-config"
    
    # Copy config
    rsync -avz --exclude='.git' --exclude='result' --exclude='testing' \
        -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        "$config_path/" nixos@"$ip":/tmp/nixos-config/
    
    log "Configuration deployed ✓"
}

# Cleanup VM
cleanup() {
    log "Cleaning up VM..."
    
    if virsh list --all | grep -q "$VM_NAME"; then
        virsh destroy "$VM_NAME" 2>/dev/null || true
        virsh undefine "$VM_NAME" --remove-all-storage
    fi
    
    rm -rf "$WORK_DIR"
    log "Cleanup complete ✓"
}

# Main command dispatcher
main() {
    case "${1:-help}" in
        "setup")
            check_prerequisites
            log "Using existing ISO: $NIXOS_ISO_PATH"
            if [[ ! -f "$NIXOS_ISO_PATH" ]]; then
                error "NixOS ISO not found at $NIXOS_ISO_PATH"
            fi
            create_base_vm "$NIXOS_ISO_PATH"
            create_base_snapshot
            ;;
        "clean")
            revert_to_clean
            ;;
        "start")
            start_vm
            ;;
        "deploy")
            local ip="${2:-$(get_vm_ip)}"
            deploy_config "$ip" "${3:-}"
            ;;
        "ip")
            get_vm_ip
            ;;
        "ssh")
            local ip="${2:-$(get_vm_ip)}"
            local user="${3:-nixos}"
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$user@$ip"
            ;;
        "cleanup")
            cleanup
            ;;
        "help"|*)
            echo "VM Manager for NixOS Agent Testing"
            echo ""
            echo "Commands:"
            echo "  setup     - Create base VM and clean snapshot"
            echo "  clean     - Revert VM to clean installer state"
            echo "  start     - Start VM and return IP"
            echo "  deploy    - Deploy nixos-config to VM"
            echo "  ip        - Get VM IP address"
            echo "  ssh       - SSH to VM"
            echo "  cleanup   - Remove VM and cleanup"
            echo "  help      - Show this help"
            ;;
    esac
}

main "$@"