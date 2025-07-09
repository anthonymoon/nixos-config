# VM Disk Images

This directory contains NixOS configurations for building ready-to-use VM disk images using nixpkgs' `make-disk-image.nix`.

## Available Images

### Minimal VM Image
- **Size**: ~2GB (4GB disk allocated)
- **Type**: Headless server
- **Format**: QCOW2
- **Partition**: Hybrid (BIOS/UEFI compatible)
- **Features**:
  - XanMod kernel with performance optimizations
  - SSH access enabled with password authentication
  - Basic CLI tools (vim, git, htop, tmux)
  - QEMU guest additions
  - Auto-resize filesystem support
  - Serial console auto-login as root

### Full VM Image
- **Size**: ~8GB (20GB disk allocated)
- **Type**: Full desktop environment
- **Format**: QCOW2
- **Partition**: Hybrid (BIOS/UEFI compatible)
- **Features**:
  - Everything from minimal image
  - dwl (Wayland tiling window manager)
  - greetd with tuigreet display manager
  - Development tools enabled
  - Gaming support enabled
  - Full workstation environment
  - VMware guest additions
  - QXL video driver support

## Building Images

```bash
# Build minimal VM image
nix run .#build-vm-minimal

# Build full VM image with desktop
nix run .#build-vm-full
```

The build process will show progress and provide the exact output file location.

## Using the Images

The built images will be in `./result/` directory and can be used with:

### QEMU/KVM
```bash
# Run minimal image
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -drive file=./result/nixos.qcow2,if=virtio \
  -net nic,model=virtio -net user,hostfwd=tcp::2222-:22

# Run full image with graphics
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -drive file=./result/nixos.qcow2,if=virtio \
  -vga qxl \
  -spice port=5900,disable-ticketing=on \
  -device virtio-serial-pci \
  -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
  -chardev spicevmc,id=spicechannel0,name=vdagent
```

### virt-manager
Import the image as a new VM, selecting "Import existing disk image" and choosing the QCOW2 file.

## Default Users
All images come with these users pre-configured:
- **root**: Password authentication enabled
- **nixos**: Password authentication enabled 
- **amoon**: SSH key authentication

SSH keys are automatically added for all users as defined in `common.nix`.