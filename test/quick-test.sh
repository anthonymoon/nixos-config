#!/usr/bin/env bash

# Quick test for VM profile
set -euo pipefail

PROFILE="vm"
VM_NAME="nixos-${PROFILE}-test"
ISO_PATH="/home/amoon/nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso"
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"

echo "Testing NixOS ${PROFILE} profile..."

# Clean up if exists
if virsh dominfo "${VM_NAME}" &>/dev/null; then
    echo "Cleaning up existing VM..."
    virsh destroy "${VM_NAME}" &>/dev/null || true
    virsh undefine "${VM_NAME}" --nvram &>/dev/null || true
fi

# Remove old disk
sudo rm -f "${DISK_PATH}"

# Create disk
echo "Creating disk..."
sudo qemu-img create -f qcow2 "${DISK_PATH}" 30G
sudo chown libvirt-qemu:libvirt-qemu "${DISK_PATH}" 2>/dev/null || true

# Create VM XML
cat > "/tmp/${VM_NAME}.xml" <<EOF
<domain type="kvm">
  <name>${VM_NAME}</name>
  <memory unit="KiB">4194304</memory>
  <vcpu placement="static">2</vcpu>
  <os>
    <type arch="x86_64" machine="pc-q35-9.0">hvm</type>
    <boot dev="cdrom"/>
    <boot dev="hd"/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode="host-passthrough" check="none"/>
  <clock offset="utc"/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="${DISK_PATH}"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="${ISO_PATH}"/>
      <target dev="sda" bus="sata"/>
      <readonly/>
    </disk>
    <controller type="sata" index="0"/>
    <controller type="pci" index="0" model="pcie-root"/>
    <interface type="bridge">
      <source bridge="virbr0"/>
      <model type="virtio"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0"/>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <graphics type="vnc" port="-1" autoport="yes" listen="127.0.0.1">
      <listen type="address" address="127.0.0.1"/>
    </graphics>
    <video>
      <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1"/>
    </video>
  </devices>
</domain>
EOF

# Define and start VM
echo "Creating VM..."
virsh define "/tmp/${VM_NAME}.xml"

echo "Starting VM..."
virsh start "${VM_NAME}"

echo ""
echo "VM ${VM_NAME} started!"
echo ""
echo "Connect to console: virsh console ${VM_NAME}"
echo "VNC display: $(virsh vncdisplay ${VM_NAME} 2>/dev/null || echo 'N/A')"
echo ""
echo "Installation command:"
echo "sudo nix run --extra-experimental-features \"nix-command flakes\" --no-write-lock-file github:anthonymoon/nixos-config#install-${PROFILE}"
echo ""

# Wait a bit and try to get IP
echo "Waiting for IP..."
sleep 10
IP=$(virsh domifaddr "${VM_NAME}" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 || true)
if [[ -n "$IP" ]]; then
    echo "VM IP: $IP"
else
    echo "No IP yet (VM still booting)"
fi