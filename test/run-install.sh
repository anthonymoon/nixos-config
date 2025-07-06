#!/usr/bin/env bash

# Run NixOS installation on VM
set -euo pipefail

VM_NAME="nixos-vm-test"
PROFILE="vm"

echo "Starting NixOS installation for ${PROFILE} profile..."
echo ""
echo "This will run the installation in the VM console."
echo ""

# Create a script to run in the VM
cat > /tmp/nixos-install-cmd.txt <<'EOF'
echo "Starting NixOS installation..."
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-vm -- --disk /dev/vda --no-confirm
EOF

echo "To install NixOS on the VM:"
echo "1. Open a new terminal"
echo "2. Run: virsh console ${VM_NAME}"
echo "3. Press Enter to get a prompt"
echo "4. Run the installation command:"
echo ""
echo "sudo nix run --extra-experimental-features \"nix-command flakes\" --no-write-lock-file github:anthonymoon/nixos-config#install-vm"
echo ""
echo "5. Select /dev/vda when prompted"
echo "6. Wait for installation to complete"
echo "7. Exit console with Ctrl+] when done"
echo ""
echo "Current VM status:"
virsh dominfo ${VM_NAME} | grep -E "(State|Id)"
echo ""
echo "IP will be available after installation at:"
echo "virsh domifaddr ${VM_NAME}"
echo ""
echo "Or SSH directly after reboot:"
echo "ssh amoon@10.10.10.109"