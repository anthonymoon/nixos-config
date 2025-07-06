# NixOS Profile Testing Results

## Test Environment
- **Host**: CachyOS (cachy.local)
- **Hypervisor**: libvirt/QEMU with virsh
- **Network**: virbr0 bridge with DHCP
- **ISO**: nixos-minimal-25.05.805766.7a732ed41ca0-x86_64-linux.iso

## Test Status

### VM Profile ✅
- **VM Name**: nixos-vm-test
- **Status**: Running
- **IP Address**: 10.10.10.109
- **Resources**: 4GB RAM, 2 vCPUs, 30GB disk
- **VNC**: 127.0.0.1:0

**Installation Command**:
```bash
virsh console nixos-vm-test
# Login as nixos (no password)
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-vm
```

### Workstation Profile 🔄
- **Status**: Pending test
- **Resources**: 8GB RAM, 6 vCPUs, 50GB disk

### Server Profile 🔄
- **Status**: Pending test
- **Resources**: 4GB RAM, 4 vCPUs, 30GB disk

## Quick Commands

### Connect to VM
```bash
# Console access
virsh console nixos-vm-test

# SSH after installation
ssh amoon@10.10.10.109
```

### Manage VMs
```bash
# List all VMs
virsh list --all

# Get VM IP
virsh domifaddr nixos-vm-test
# Or check ARP
arp -n | grep virbr0

# Stop VM
virsh shutdown nixos-vm-test

# Start VM
virsh start nixos-vm-test

# Delete VM
virsh destroy nixos-vm-test
virsh undefine nixos-vm-test --nvram
sudo rm -f /var/lib/libvirt/images/nixos-vm-test.qcow2
```

### Test Other Profiles
```bash
# Interactive menu
./test/virsh-profile-test.sh

# Quick test specific profile
./test/quick-test.sh  # Edit PROFILE variable
```

## Notes
- VMs boot from NixOS minimal ISO
- Manual installation required via console
- DHCP provides automatic IP assignment
- All VMs use UEFI boot (when supported)