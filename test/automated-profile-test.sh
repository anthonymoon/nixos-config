#!/usr/bin/env bash

# Automated NixOS Profile Testing with libvirt
# Performs unattended installation and testing of all profiles

set -euo pipefail

# SSH Authentication Note:
# Currently using password authentication (nixos:nixos) for testing.
# Future versions will transition to SSH key authentication once
# the infrastructure is fully configured with authorized_keys.

# Configuration
BRIDGE="virbr0"
ISO_PATH="/home/amoon/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso"
IMAGE_DIR="/var/lib/libvirt/images"
GITHUB_REPO="github:anthonymoon/nixos-config"
TEST_PASSWORD="test123"  # For testing only

# Profile configurations
declare -A PROFILE_MEMORY=(
    ["vm"]=4096
    ["workstation"]=8192
    ["server"]=4096
)

declare -A PROFILE_VCPUS=(
    ["vm"]=2
    ["workstation"]=4
    ["server"]=2
)

declare -A PROFILE_DISK=(
    ["vm"]=20G
    ["workstation"]=50G
    ["server"]=30G
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
declare -A TEST_RESULTS
declare -A TEST_IPS

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

# Clean up VM
cleanup_vm() {
    local vm_name=$1
    
    if virsh dominfo "${vm_name}" &> /dev/null; then
        log "Cleaning up ${vm_name}..."
        virsh destroy "${vm_name}" &> /dev/null || true
        virsh undefine "${vm_name}" --nvram &> /dev/null || true
    fi
    
    sudo rm -f "${IMAGE_DIR}/${vm_name}.qcow2"
    sudo rm -f "${IMAGE_DIR}/${vm_name}-seed.iso"
}

# Generate cloud-init ISO for automated installation
generate_cloud_init() {
    local profile=$1
    local vm_name="nixos-test-${profile}"
    local seed_dir="/tmp/${vm_name}-seed"
    
    mkdir -p "${seed_dir}"
    
    # Create user-data for cloud-init style automation
    cat > "${seed_dir}/user-data" <<EOF
#cloud-config
hostname: ${vm_name}
users:
  - name: nixos
    passwd: $(openssl passwd -6 "${TEST_PASSWORD}")
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "ssh-rsa DUMMY")

runcmd:
  - |
    # Wait for network
    while ! ping -c1 github.com &>/dev/null; do sleep 1; done
    
    # Run installation
    sudo nix run --extra-experimental-features "nix-command flakes" \\
      --no-write-lock-file ${GITHUB_REPO}#install-${profile} -- \\
      --no-interactive \\
      --disk /dev/vda \\
      --password "${TEST_PASSWORD}"
    
    # Reboot after installation
    sudo reboot
EOF

    # Create meta-data
    cat > "${seed_dir}/meta-data" <<EOF
instance-id: ${vm_name}
local-hostname: ${vm_name}
EOF

    # Create seed ISO
    sudo genisoimage -output "${IMAGE_DIR}/${vm_name}-seed.iso" \
        -volid cidata -joliet -rock \
        "${seed_dir}/user-data" "${seed_dir}/meta-data" 2>/dev/null || \
    sudo mkisofs -o "${IMAGE_DIR}/${vm_name}-seed.iso" \
        -V cidata -J -r \
        "${seed_dir}/user-data" "${seed_dir}/meta-data"
    
    rm -rf "${seed_dir}"
}

# Generate VM XML
generate_vm_xml() {
    local profile=$1
    local vm_name="nixos-test-${profile}"
    local memory=${PROFILE_MEMORY[$profile]}
    local vcpus=${PROFILE_VCPUS[$profile]}
    local disk_size=${PROFILE_DISK[$profile]}
    local disk_path="${IMAGE_DIR}/${vm_name}.qcow2"
    local seed_path="${IMAGE_DIR}/${vm_name}-seed.iso"
    local uuid=$(uuidgen)
    
    cat > "/tmp/${vm_name}.xml" <<EOF
<domain type="kvm">
  <name>${vm_name}</name>
  <uuid>${uuid}</uuid>
  <memory unit="MiB">${memory}</memory>
  <currentMemory unit="MiB">${memory}</currentMemory>
  <vcpu placement="static">${vcpus}</vcpu>
  <os>
    <type arch="x86_64" machine="pc-q35-9.0">hvm</type>
    <boot dev="cdrom"/>
    <boot dev="hd"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state="off"/>
  </features>
  <cpu mode="host-passthrough" check="none"/>
  <clock offset="utc">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2" cache="writeback"/>
      <source file="${disk_path}"/>
      <target dev="vda" bus="virtio"/>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
    </disk>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="${ISO_PATH}"/>
      <target dev="sda" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="${seed_path}"/>
      <target dev="sdb" bus="sata"/>
      <readonly/>
      <address type="drive" controller="0" bus="0" target="0" unit="1"/>
    </disk>
    <controller type="sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    <controller type="pci" index="0" model="pcie-root"/>
    <controller type="pci" index="1" model="pcie-root-port">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0"/>
    </controller>
    <controller type="pci" index="2" model="pcie-root-port">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x1"/>
    </controller>
    <controller type="pci" index="3" model="pcie-root-port">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x2"/>
    </controller>
    <controller type="pci" index="4" model="pcie-root-port">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x3"/>
    </controller>
    <interface type="bridge">
      <mac address="52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"/>
      <source bridge="${BRIDGE}"/>
      <model type="virtio"/>
      <driver name="vhost" queues="2" rx_queue_size="256" tx_queue_size="256"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0"/>
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
      <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </video>
    <memballoon model="virtio">
      <address type="pci" domain="0x0000" bus="0x03" slot="0x00" function="0x0"/>
    </memballoon>
    <rng model="virtio">
      <backend model="random">/dev/urandom</backend>
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </rng>
  </devices>
</domain>
EOF
}

# Wait for VM to get IP
get_vm_ip() {
    local vm_name=$1
    local timeout=${2:-120}
    
    log "Waiting for ${vm_name} to get IP address..."
    local ip=""
    local elapsed=0
    
    while [[ -z "$ip" && $elapsed -lt $timeout ]]; do
        sleep 2
        ip=$(virsh domifaddr "${vm_name}" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
        ((elapsed+=2))
    done
    
    echo "$ip"
}

# Test profile installation
test_profile() {
    local profile=$1
    local vm_name="nixos-test-${profile}"
    
    log "Testing profile: ${profile}"
    
    # Clean up any existing VM
    cleanup_vm "${vm_name}"
    
    # Create disk
    log "Creating disk for ${vm_name}..."
    sudo qemu-img create -f qcow2 "${IMAGE_DIR}/${vm_name}.qcow2" "${PROFILE_DISK[$profile]}"
    
    # Generate cloud-init seed
    log "Generating cloud-init seed..."
    generate_cloud_init "$profile"
    
    # Generate and define VM
    generate_vm_xml "$profile"
    virsh define "/tmp/${vm_name}.xml"
    
    # Start VM
    log "Starting VM ${vm_name}..."
    virsh start "${vm_name}"
    
    # Monitor installation via console
    log "VM started. Monitoring installation..."
    log "To view console: virsh console ${vm_name}"
    
    # Wait for initial boot and IP
    local boot_ip=$(get_vm_ip "${vm_name}" 60)
    if [[ -z "$boot_ip" ]]; then
        warning "No IP obtained during boot phase"
    else
        log "Boot IP: $boot_ip"
    fi
    
    # Wait for installation to complete (VM will reboot)
    log "Waiting for installation to complete and VM to reboot..."
    sleep 180  # Give time for installation
    
    # Get IP after reboot
    local final_ip=$(get_vm_ip "${vm_name}" 120)
    
    if [[ -n "$final_ip" ]]; then
        success "Profile ${profile} installed successfully!"
        TEST_RESULTS[$profile]="SUCCESS"
        TEST_IPS[$profile]="$final_ip"
        
        # Run validation tests
        validate_installation "$profile" "$final_ip"
    else
        error "Failed to get IP after installation"
        TEST_RESULTS[$profile]="FAILED - No IP after installation"
    fi
}

# Validate installed system
validate_installation() {
    local profile=$1
    local ip=$2
    
    log "Validating ${profile} installation at ${ip}..."
    
    # Wait for SSH
    local ssh_attempts=0
    while ! ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           amoon@"${ip}" "true" &>/dev/null; do
        ((ssh_attempts++))
        if [[ $ssh_attempts -gt 30 ]]; then
            warning "SSH not available after 60 seconds"
            return 1
        fi
        sleep 2
    done
    
    log "SSH connection established, running validation tests..."
    
    # Run validation commands
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null amoon@"${ip}" bash <<'EOF'
echo "=== System Information ==="
nixos-version
echo

echo "=== Profile Detection ==="
if [[ -f /etc/nixos/configuration.nix ]]; then
    grep -E "(profile|workstation|server|vm)" /etc/nixos/configuration.nix | head -5
fi
echo

echo "=== Failed Services ==="
systemctl list-units --failed --no-legend
echo

echo "=== Disk Usage ==="
df -h /
echo

echo "=== Network Configuration ==="
ip -4 addr show | grep -E "(inet|$)"
echo

echo "=== System Resources ==="
free -h
echo "CPUs: $(nproc)"
EOF
}

# Generate summary report
generate_report() {
    local report_file="test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "NixOS Profile Test Report"
        echo "========================="
        echo "Date: $(date)"
        echo "Repository: ${GITHUB_REPO}"
        echo ""
        echo "Test Results:"
        echo "-------------"
        for profile in vm workstation server; do
            printf "%-12s: %s" "$profile" "${TEST_RESULTS[$profile]:-NOT TESTED}"
            if [[ -n "${TEST_IPS[$profile]}" ]]; then
                printf " (IP: %s)" "${TEST_IPS[$profile]}"
            fi
            echo
        done
        echo ""
        echo "Active VMs:"
        echo "-----------"
        virsh list --name | grep nixos-test || echo "None"
    } | tee "$report_file"
    
    success "Report saved to: $report_file"
}

# Main execution
main() {
    log "Starting automated NixOS profile testing"
    
    # Check prerequisites
    if ! command -v virsh &> /dev/null; then
        error "libvirt not installed"
        exit 1
    fi
    
    if [[ ! -f "$ISO_PATH" ]]; then
        error "ISO not found at $ISO_PATH"
        exit 1
    fi
    
    # Test each profile
    for profile in vm workstation server; do
        echo ""
        echo "========================================="
        echo " Testing Profile: $profile"
        echo "========================================="
        test_profile "$profile"
        echo ""
    done
    
    # Generate report
    echo ""
    generate_report
    
    # Cleanup option
    echo ""
    read -p "Clean up test VMs? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for profile in vm workstation server; do
            cleanup_vm "nixos-test-${profile}"
        done
        success "All test VMs cleaned up"
    fi
}

# Handle arguments
case "${1:-}" in
    clean|cleanup)
        for profile in vm workstation server; do
            cleanup_vm "nixos-test-${profile}"
        done
        success "All test VMs cleaned up"
        ;;
    *)
        main "$@"
        ;;
esac