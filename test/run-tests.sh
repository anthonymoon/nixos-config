#!/usr/bin/env bash

# Run NixOS profile tests
set -euo pipefail

# SSH Authentication Note:
# Currently using password authentication (nixos:nixos) for testing.
# Future versions will transition to SSH key authentication once
# the infrastructure is fully configured with authorized_keys.

# Test configuration
ISO_PATH="/home/amoon/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso"
PROFILES=("vm" "workstation" "server")
TEST_DIR="$(dirname "$0")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Start VM test
test_vm_profile() {
    local profile=$1
    local vm_name="nixos-${profile}-test"
    
    log "Testing ${profile} profile..."
    
    # Clean up if exists
    if virsh dominfo "${vm_name}" &>/dev/null; then
        virsh destroy "${vm_name}" &>/dev/null || true
        virsh undefine "${vm_name}" --nvram &>/dev/null || true
        sudo rm -f "/var/lib/libvirt/images/${vm_name}.qcow2"
    fi
    
    # Use the menu script to create VM
    echo "1" | timeout 10 "${TEST_DIR}/virsh-profile-test.sh" 2>&1 | grep -E "(Setting up|Creating|started)" || true
    
    # Check if VM was created
    if virsh dominfo "${vm_name}" &>/dev/null; then
        success "VM ${vm_name} created successfully"
        
        # Get VNC display
        local vnc=$(virsh vncdisplay "${vm_name}" 2>/dev/null || echo "N/A")
        
        echo ""
        echo "VM Details:"
        echo "  Name: ${vm_name}"
        echo "  VNC: ${vnc}"
        echo "  Console: virsh console ${vm_name}"
        echo ""
        echo "To install:"
        echo "  1. Connect to console: virsh console ${vm_name}"
        echo "  2. Run: sudo nix run --extra-experimental-features \"nix-command flakes\" --no-write-lock-file github:anthonymoon/nixos-config#install-${profile}"
        echo ""
        
        # Try to get IP
        sleep 5
        local ip=$(virsh domifaddr "${vm_name}" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
        if [[ -n "$ip" ]]; then
            echo "IP Address: $ip"
        fi
        
        return 0
    else
        error "Failed to create VM ${vm_name}"
        return 1
    fi
}

# Main execution
main() {
    log "Starting NixOS profile tests"
    
    # Check prerequisites
    if ! command -v virsh &>/dev/null; then
        error "virsh not found. Please install libvirt."
        exit 1
    fi
    
    if [[ ! -f "$ISO_PATH" ]]; then
        error "ISO not found at $ISO_PATH"
        exit 1
    fi
    
    # Check libvirt is running
    if ! virsh list &>/dev/null; then
        error "Cannot connect to libvirt. Is libvirtd running?"
        exit 1
    fi
    
    # Check virbr0 exists
    if ! virsh net-info default &>/dev/null; then
        error "Default network not found. Run: sudo virsh net-start default"
        exit 1
    fi
    
    success "All prerequisites met"
    echo ""
    
    # Test VM profile first
    log "Creating VM for 'vm' profile test..."
    if test_vm_profile "vm"; then
        echo ""
        echo "VM profile test VM created successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Connect to the VM console: virsh console nixos-vm-test"
        echo "2. Login as 'nixos' (no password needed in installer)"
        echo "3. Run the installation command shown above"
        echo "4. After installation, the VM will reboot"
        echo "5. Get the IP: virsh domifaddr nixos-vm-test"
        echo ""
        echo "To test other profiles:"
        echo "  ${TEST_DIR}/virsh-profile-test.sh"
        echo ""
        echo "Current VMs:"
        virsh list --all | grep nixos || echo "  None running"
    fi
}

# Run
main "$@"