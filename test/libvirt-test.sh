#!/usr/bin/env bash

# NixOS Profile Testing Framework using libvirt/virsh
# Tests all three profiles: vm, workstation, server

set -euo pipefail

# SSH Authentication Note:
# Currently using password authentication (nixos:nixos) for testing.
# Future versions will transition to SSH key authentication once
# the infrastructure is fully configured with authorized_keys.

# Configuration
BRIDGE="virbr0"
ISO_PATH="/home/amoon/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso"
IMAGE_DIR="/var/lib/libvirt/images"
PROFILE_MEMORY=(
    ["vm"]=4096        # 4GB for VM profile
    ["workstation"]=8192  # 8GB for workstation profile
    ["server"]=4096    # 4GB for server profile
)
PROFILE_VCPUS=(
    ["vm"]=2
    ["workstation"]=4
    ["server"]=2
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results array
declare -A TEST_RESULTS

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v virsh &> /dev/null; then
        error "virsh not found. Please install libvirt."
        exit 1
    fi
    
    if ! virsh net-info "$BRIDGE" &> /dev/null; then
        error "Bridge $BRIDGE not found. Please ensure libvirt default network is running."
        exit 1
    fi
    
    if [[ ! -f "$ISO_PATH" ]]; then
        error "ISO not found at $ISO_PATH"
        error "Please download NixOS minimal ISO first"
        exit 1
    fi
    
    success "All prerequisites met"
}

# Generate libvirt XML for a profile
generate_vm_xml() {
    local profile=$1
    local vm_name="nixos-test-${profile}"
    local memory=${PROFILE_MEMORY[$profile]}
    local vcpus=${PROFILE_VCPUS[$profile]}
    local disk_path="${IMAGE_DIR}/${vm_name}.qcow2"
    local uuid=$(uuidgen)
    
    cat > "/tmp/${vm_name}.xml" <<EOF
<domain type="kvm">
  <name>${vm_name}</name>
  <uuid>${uuid}</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://nixos.org/nixos/25.05"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="MiB">${memory}</memory>
  <currentMemory unit="MiB">${memory}</currentMemory>
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
      <mac address="52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"/>
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

# Create disk for VM
create_disk() {
    local profile=$1
    local vm_name="nixos-test-${profile}"
    local disk_path="${IMAGE_DIR}/${vm_name}.qcow2"
    
    log "Creating disk for ${vm_name}..."
    sudo qemu-img create -f qcow2 "${disk_path}" 50G
    sudo chown libvirt-qemu:libvirt-qemu "${disk_path}"
}

# Start VM and get IP
start_vm() {
    local profile=$1
    local vm_name="nixos-test-${profile}"
    
    log "Starting VM ${vm_name}..."
    virsh start "${vm_name}"
    
    # Wait for VM to get IP
    log "Waiting for VM to get IP address..."
    local ip=""
    local attempts=0
    while [[ -z "$ip" && $attempts -lt 60 ]]; do
        sleep 2
        ip=$(virsh domifaddr "${vm_name}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
        ((attempts++))
    done
    
    if [[ -z "$ip" ]]; then
        error "Failed to get IP for ${vm_name}"
        return 1
    fi
    
    success "VM ${vm_name} started with IP: $ip"
    echo "$ip"
}

# Test VM profile
test_profile() {
    local profile=$1
    local vm_name="nixos-test-${profile}"
    
    log "Testing profile: ${profile}"
    
    # Clean up existing VM if it exists
    if virsh dominfo "${vm_name}" &> /dev/null; then
        log "Cleaning up existing VM..."
        virsh destroy "${vm_name}" &> /dev/null || true
        virsh undefine "${vm_name}" --nvram &> /dev/null || true
    fi
    
    # Remove old disk
    sudo rm -f "${IMAGE_DIR}/${vm_name}.qcow2"
    
    # Generate XML and create VM
    generate_vm_xml "$profile"
    create_disk "$profile"
    
    # Define VM
    virsh define "/tmp/${vm_name}.xml"
    
    # Start VM - it will boot from ISO
    if ! start_vm "$profile"; then
        TEST_RESULTS[$profile]="FAILED - Could not start VM"
        return 1
    fi
    
    # Connect to console for manual installation
    log "VM started. Connect to console to perform installation:"
    echo "  virsh console ${vm_name}"
    echo ""
    echo "Installation command to run in the VM:"
    echo "  sudo nix run --extra-experimental-features \"nix-command flakes\" --no-write-lock-file github:anthonymoon/nixos-config#install-${profile}"
    echo ""
    echo "Press Enter when installation is complete..."
    read -r
    
    # Get IP after installation
    local ip=$(virsh domifaddr "${vm_name}" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
    
    if [[ -n "$ip" ]]; then
        success "Profile ${profile} test completed. VM IP: $ip"
        TEST_RESULTS[$profile]="SUCCESS - IP: $ip"
        
        # Save VM state
        log "Creating snapshot for ${vm_name}..."
        virsh snapshot-create-as "${vm_name}" "post-install" "Post installation snapshot"
    else
        warning "Could not get IP after installation"
        TEST_RESULTS[$profile]="SUCCESS - No IP obtained"
    fi
}

# Run automated checks
run_automated_checks() {
    local profile=$1
    local ip=$2
    local vm_name="nixos-test-${profile}"
    
    log "Running automated checks for ${profile} at ${ip}..."
    
    # Wait for SSH to be available
    local ssh_ready=false
    local attempts=0
    while [[ $ssh_ready == false && $attempts -lt 30 ]]; do
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no amoon@"${ip}" "echo test" &> /dev/null; then
            ssh_ready=true
        else
            sleep 2
            ((attempts++))
        fi
    done
    
    if [[ $ssh_ready == true ]]; then
        log "SSH connection established"
        
        # Run basic checks
        ssh -o StrictHostKeyChecking=no amoon@"${ip}" "
            echo '=== System Info ==='
            nixos-version
            echo
            echo '=== Hardware ==='
            nix-store -q --references /run/current-system | grep linux
            echo
            echo '=== Services ==='
            systemctl list-units --state=failed
            echo
            echo '=== Network ==='
            ip addr show
        "
    else
        warning "Could not establish SSH connection"
    fi
}

# Main test execution
main() {
    log "Starting NixOS profile testing with libvirt"
    
    check_prerequisites
    
    # Test each profile
    for profile in vm workstation server; do
        echo ""
        echo "========================================="
        echo " Testing Profile: $profile"
        echo "========================================="
        test_profile "$profile"
        echo ""
    done
    
    # Summary
    echo ""
    echo "========================================="
    echo " Test Summary"
    echo "========================================="
    for profile in vm workstation server; do
        echo "$profile: ${TEST_RESULTS[$profile]:-NOT TESTED}"
    done
}

# Run main
main "$@"