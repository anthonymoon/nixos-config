#!/usr/bin/env bash

# Simple libvirt/virsh testing for NixOS profiles
# Uses the provided XML template with minimal modifications

set -euo pipefail

# SSH Authentication Note:
# Currently using password authentication (nixos:nixos) for testing.
# Future versions will transition to SSH key authentication once
# the infrastructure is fully configured with authorized_keys.

# Configuration
PROFILES=("vm" "workstation" "server")
ISO_PATH="/home/amoon/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso"
IMAGE_DIR="/var/lib/libvirt/images"
BRIDGE="virbr0"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

# Generate VM XML based on template
create_vm_xml() {
    local profile=$1
    local vm_name="nixos-${profile}-test"
    local uuid=$(uuidgen)
    local mac="52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"
    local disk_path="${IMAGE_DIR}/${vm_name}.qcow2"
    
    # Memory and CPU based on profile
    local memory=4194304  # 4GB default
    local vcpus=4
    
    case $profile in
        vm)
            memory=4194304  # 4GB
            vcpus=2
            ;;
        workstation)
            memory=8388608  # 8GB
            vcpus=6
            ;;
        server)
            memory=4194304  # 4GB
            vcpus=4
            ;;
    esac
    
    cat > "/tmp/${vm_name}.xml" <<EOF
<domain type="kvm">
  <name>${vm_name}</name>
  <uuid>${uuid}</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://nixos.org/nixos/25.05"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="KiB">${memory}</memory>
  <currentMemory unit="KiB">${memory}</currentMemory>
  <vcpu placement="static">${vcpus}</vcpu>
  <os firmware="efi">
    <type arch="x86_64" machine="pc-q35-10.0">hvm</type>
    <firmware>
      <feature enabled="no" name="enrolled-keys"/>
      <feature enabled="no" name="secure-boot"/>
    </firmware>
    <loader readonly="yes" type="pflash" format="raw">/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram template="/usr/share/edk2/x64/OVMF_VARS.4m.fd" format="raw">/var/lib/libvirt/qemu/nvram/${vm_name}_VARS.fd</nvram>
  </os>
  <features>
    <acpi/>
    <apic eoi="on"/>
    <kvm>
      <hidden state="on"/>
      <hint-dedicated state="on"/>
      <poll-control state="on"/>
      <pv-ipi state="on"/>
    </kvm>
    <vmport state="off"/>
    <ioapic driver="kvm"/>
  </features>
  <cpu mode="host-passthrough" check="none"/>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
    <timer name="tsc" present="yes" mode="native"/>
    <timer name="kvmclock" present="yes"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2" cache="none" io="native" discard="unmap"/>
      <source file="${disk_path}"/>
      <target dev="vda" bus="virtio"/>
      <boot order="2"/>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
    </disk>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="${ISO_PATH}"/>
      <target dev="sda" bus="sata"/>
      <readonly/>
      <boot order="1"/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    <controller type="pci" index="0" model="pcie-root"/>
    <controller type="pci" index="1" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="1" port="0x10"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="2" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="2" port="0x11"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x1"/>
    </controller>
    <controller type="pci" index="3" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="3" port="0x12"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x2"/>
    </controller>
    <controller type="pci" index="4" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="4" port="0x13"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x3"/>
    </controller>
    <controller type="virtio-serial" index="0">
      <address type="pci" domain="0x0000" bus="0x03" slot="0x00" function="0x0"/>
    </controller>
    <controller type="usb" index="0" model="qemu-xhci" ports="5">
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </controller>
    <controller type="sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    <interface type="bridge">
      <mac address="${mac}"/>
      <source bridge="${BRIDGE}"/>
      <model type="virtio"/>
      <driver name="vhost" queues="4" rx_queue_size="256" tx_queue_size="256"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <channel type="unix">
      <target type="virtio" name="org.qemu.guest_agent.0"/>
      <address type="virtio-serial" controller="0" bus="0" port="1"/>
    </channel>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <graphics type="vnc" port="-1" autoport="yes" listen="127.0.0.1">
      <listen type="address" address="127.0.0.1"/>
    </graphics>
    <video>
      <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1" primary="yes"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    <watchdog model="itco" action="reset"/>
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x04" slot="0x01" function="0x0"/>
    </memballoon>
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x02" function="0x0"/>
    </rng>
  </devices>
</domain>
EOF
}

# Create or recreate VM
setup_vm() {
    local profile=$1
    local vm_name="nixos-${profile}-test"
    
    log "Setting up VM for profile: ${profile}"
    
    # Clean up if exists
    if virsh dominfo "${vm_name}" &>/dev/null; then
        log "Removing existing VM..."
        virsh destroy "${vm_name}" &>/dev/null || true
        virsh undefine "${vm_name}" --nvram &>/dev/null || true
    fi
    
    # Create disk
    local disk_path="${IMAGE_DIR}/${vm_name}.qcow2"
    if [[ -f "$disk_path" ]]; then
        sudo rm -f "$disk_path"
    fi
    
    log "Creating 50GB disk..."
    sudo qemu-img create -f qcow2 "$disk_path" 50G
    sudo chown libvirt-qemu:libvirt-qemu "$disk_path" 2>/dev/null || true
    
    # Create and define VM
    create_vm_xml "$profile"
    virsh define "/tmp/${vm_name}.xml"
    
    success "VM ${vm_name} created"
}

# Start VM and get IP
start_vm() {
    local profile=$1
    local vm_name="nixos-${profile}-test"
    
    log "Starting ${vm_name}..."
    virsh start "${vm_name}"
    
    echo ""
    echo "VM started. To connect:"
    echo "  Console: virsh console ${vm_name}"
    echo "  VNC: virsh vncdisplay ${vm_name}"
    echo ""
    echo "Install command to run in VM:"
    echo "  sudo nix run --extra-experimental-features \"nix-command flakes\" --no-write-lock-file github:anthonymoon/nixos-config#install-${profile}"
    echo ""
}

# Get VM IP
get_ip() {
    local profile=$1
    local vm_name="nixos-${profile}-test"
    
    local ip=$(virsh domifaddr "${vm_name}" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    
    if [[ -n "$ip" ]]; then
        success "VM IP: $ip"
        echo "SSH: ssh amoon@$ip"
    else
        error "No IP address found (VM might still be booting)"
    fi
}

# List all test VMs
list_vms() {
    echo "Test VMs:"
    virsh list --all | grep -E "(nixos-(vm|workstation|server)-test|Name)" || echo "No test VMs found"
}

# Main menu
show_menu() {
    echo ""
    echo "NixOS Profile Testing with libvirt"
    echo "=================================="
    echo "1) Setup VM (vm profile)"
    echo "2) Setup VM (workstation profile)"
    echo "3) Setup VM (server profile)"
    echo "4) Start VM"
    echo "5) Get VM IP"
    echo "6) List all test VMs"
    echo "7) Clean up all test VMs"
    echo "8) Run all tests sequentially"
    echo "9) Exit"
    echo ""
}

# Clean up all test VMs
cleanup_all() {
    for profile in "${PROFILES[@]}"; do
        local vm_name="nixos-${profile}-test"
        if virsh dominfo "${vm_name}" &>/dev/null; then
            log "Cleaning up ${vm_name}..."
            virsh destroy "${vm_name}" &>/dev/null || true
            virsh undefine "${vm_name}" --nvram &>/dev/null || true
            sudo rm -f "${IMAGE_DIR}/${vm_name}.qcow2"
        fi
    done
    success "All test VMs cleaned up"
}

# Test all profiles
test_all() {
    for profile in "${PROFILES[@]}"; do
        echo ""
        echo "Testing profile: ${profile}"
        echo "------------------------"
        setup_vm "$profile"
        start_vm "$profile"
        echo ""
        echo "Press Enter to continue with next profile..."
        read -r
    done
}

# Main loop
main() {
    # Check prerequisites
    if ! command -v virsh &>/dev/null; then
        error "virsh not found. Install libvirt first."
        exit 1
    fi
    
    if [[ ! -f "$ISO_PATH" ]]; then
        error "ISO not found at $ISO_PATH"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) setup_vm "vm"; start_vm "vm";;
            2) setup_vm "workstation"; start_vm "workstation";;
            3) setup_vm "server"; start_vm "server";;
            4)
                read -p "Profile (vm/workstation/server): " profile
                start_vm "$profile"
                ;;
            5)
                read -p "Profile (vm/workstation/server): " profile
                get_ip "$profile"
                ;;
            6) list_vms;;
            7) cleanup_all;;
            8) test_all;;
            9) exit 0;;
            *) echo "Invalid option";;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run
main "$@"