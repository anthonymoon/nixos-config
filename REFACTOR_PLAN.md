# NixOS Configuration Refactor Plan

## Core Principles
1. **Single Source of Truth** - One flake, multiple profiles
2. **Declarative Hardware** - No runtime detection, explicit configuration  
3. **Modular Profiles** - vm, workstation, server, minimal profiles
4. **Zero Templates** - Use profiles instead of separate templates
5. **Bulletproof Defaults** - Safe assumptions, explicit overrides

## New Structure

```
nixos-config/
├── flake.nix                    # Single flake with all profiles
├── profiles/
│   ├── base.nix                # Common baseline (packages, users, etc.)
│   ├── vm.nix                  # VM-specific optimizations
│   ├── workstation.nix         # Gaming, desktop, media
│   ├── server.nix              # Headless, services, networking
│   └── minimal.nix             # Bare minimum system
├── hardware/
│   ├── vm-qemu.nix            # Standard QEMU VM hardware
│   ├── vm-vmware.nix          # VMware-specific hardware
│   ├── intel-nuc.nix          # Intel NUC hardware profile
│   └── generic-uefi.nix       # Generic UEFI system
├── install/
│   └── install.sh             # Single, bulletproof installer
└── modules/
    ├── desktop/               # Desktop environment modules
    ├── gaming/               # Gaming-specific modules
    ├── server/               # Server service modules
    └── development/          # Development tool modules
```

## Flake Structure

```nix
{
  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    
    # Hardware + Profile combinations
    configurations = {
      # VM configurations
      "vm-minimal" = { hardware = "vm-qemu"; profile = "minimal"; };
      "vm-desktop" = { hardware = "vm-qemu"; profile = "workstation"; };
      
      # Workstation configurations  
      "workstation" = { hardware = "generic-uefi"; profile = "workstation"; };
      "gaming-rig" = { hardware = "intel-nuc"; profile = "workstation"; };
      
      # Server configurations
      "server" = { hardware = "generic-uefi"; profile = "server"; };
    };
    
    mkSystem = name: { hardware, profile }: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./profiles/base.nix
        ./profiles/${profile}.nix
        ./hardware/${hardware}.nix
        home-manager.nixosModules.home-manager
      ];
    };
  in {
    nixosConfigurations = nixpkgs.lib.mapAttrs mkSystem configurations;
    
    # Single installer app
    apps.${system}.install = {
      type = "app";
      program = "${./install/install.sh}";
    };
  };
}
```

## Profile-Based Approach

### Base Profile (profiles/base.nix)
```nix
{ pkgs, ... }: {
  # Essential system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Core packages everyone needs
  environment.systemPackages = with pkgs; [ vim git curl ];
  
  # Standard user setup
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
  
  # Security defaults
  security.sudo.wheelNeedsPassword = false;
  networking.firewall.enable = true;
  
  system.stateVersion = "24.05";
}
```

### VM Profile (profiles/vm.nix)
```nix
{ ... }: {
  # VM-specific optimizations
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;
  
  # Minimal services for VMs
  services.openssh.enable = true;
  networking.networkmanager.enable = true;
  
  # Fast boot for VMs
  systemd.services.NetworkManager-wait-online.enable = false;
  
  # VM-friendly settings
  powerManagement.enable = false;
  services.thermald.enable = false;
}
```

### Hardware Profiles (hardware/vm-qemu.nix)
```nix
{ ... }: {
  # Standard QEMU VM hardware
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.kernelModules = [ ];
  
  # Standard VM disk layout
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
  
  # VM-optimized settings
  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.enableAllFirmware = false;
}
```

## Bulletproof Installation

### Single install.sh Script
```bash
#!/usr/bin/env bash
set -euo pipefail

# Auto-detect or prompt for configuration
select_config() {
    echo "Available configurations:"
    echo "1) vm-minimal     - Minimal VM setup"
    echo "2) vm-desktop     - VM with desktop"
    echo "3) workstation    - Full workstation setup"
    echo "4) server         - Headless server"
    
    read -p "Select configuration [1-4]: " choice
    case $choice in
        1) echo "vm-minimal" ;;
        2) echo "vm-desktop" ;;
        3) echo "workstation" ;;
        4) echo "server" ;;
        *) echo "vm-minimal" ;;  # Safe default
    esac
}

# Bulletproof disk setup
setup_disk() {
    local disk="/dev/vda"
    
    # Partition with labels (not UUIDs for initial install)
    parted $disk --script -- mklabel gpt
    parted $disk --script -- mkpart ESP fat32 1MB 512MB
    parted $disk --script -- set 1 esp on
    parted $disk --script -- mkpart primary 512MB 100%
    
    # Format with predictable labels
    mkfs.fat -F32 -n boot ${disk}1
    mkfs.ext4 -L nixos ${disk}2
    
    # Mount
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
}

# Main installation
main() {
    local config=$(select_config)
    
    setup_disk
    
    # Generate minimal hardware config
    nixos-generate-config --root /mnt
    
    # Install with selected configuration
    nixos-install --flake "github:anthonymoon/nixos-config#${config}"
}

main "$@"
```

## Key Improvements

### 1. **Zero Runtime Detection**
- No filesystem probing or hardware detection
- Explicit hardware profiles selected at install time
- Deterministic behavior across environments

### 2. **Predictable Labels** 
- Use filesystem labels (`nixos`, `boot`) instead of UUIDs
- Labels are set during partitioning, not discovered
- Eliminates UUID/partition-label confusion

### 3. **Profile Composition**
- `base.nix` provides foundation
- Profile adds layer (vm, workstation, server)
- Hardware profile defines physical characteristics
- No conditional logic based on runtime detection

### 4. **Single Install Path**
- One installer script for all configurations
- User selects profile at install time
- No template complexity or version drift

### 5. **Fail-Safe Defaults**
- Every configuration includes working defaults
- Minimal viable system in every profile
- Progressive enhancement, not feature removal

### 6. **Clear Separation of Concerns**
- Hardware = physical characteristics
- Profile = use case and services
- Base = universal requirements
- Modules = optional features

## Migration Strategy

1. **Phase 1**: Create new structure alongside existing
2. **Phase 2**: Port personal config to new workstation profile  
3. **Phase 3**: Test VM profiles extensively
4. **Phase 4**: Replace current structure entirely
5. **Phase 5**: Update documentation and examples

This approach eliminates the major pain points while maintaining all functionality in a much more maintainable structure.