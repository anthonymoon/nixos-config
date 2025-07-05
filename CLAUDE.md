# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive NixOS/nix-darwin configuration using Nix Flakes, designed for both macOS and NixOS systems with automatic VM detection and optimization.

## Essential Commands

### Building and Deployment
```bash
# Test configuration locally
./scripts/test-local.sh

# Build configuration
nix run .#build

# Build and switch to new generation  
nix run .#build-switch

# Fresh NixOS installation
sudo nix run --extra-experimental-features 'nix-command flakes' github:anthonymoon/nixos-config#install

# Update flake inputs
nix flake update
```

### Rock-Solid /dev/vda Installation
The install scripts provide bulletproof installation for VMs and systems using /dev/vda:

```bash
# For standard installation
sudo nix run --extra-experimental-features 'nix-command flakes' github:anthonymoon/nixos-config#install

# For installation with secrets
sudo nix run --extra-experimental-features 'nix-command flakes' github:anthonymoon/nixos-config#install-with-secrets
```

**Installation Process:**
1. **Robust Partitioning**: GPT with 512MB EFI (/dev/vda1) + remaining space for root (/dev/vda2)
2. **Validation**: Multiple checks ensure partitions are created correctly
3. **Hardware Config**: Auto-generated with UUID validation (no partition labels)
4. **Boot Verification**: Confirms EFI bootloader installation
5. **Configuration Validation**: Flake syntax and hardware config correctness

### Development Workflow
1. Make changes to configuration files
2. Run `./scripts/test-local.sh` to validate
3. Run `nix run .#build-switch` to apply changes
4. For fresh installs, hardware config is auto-generated

## Architecture

### Flake Structure
- **flake.nix**: Central hub defining inputs, outputs, and system configurations
- **nixosConfigurations.personal**: Main personal system (x86_64-linux)
- **apps**: Management commands (apply, build-switch, install, key management)
- **templates**: Starter configurations for new users

### Module Organization
```
modules/
├── shared/           # Cross-platform (macOS/NixOS) configuration
│   ├── packages.nix  # Common packages
│   └── home-manager.nix  # Shared home config
├── nixos/           # NixOS-specific configuration
│   ├── packages.nix  # System packages
│   └── home-manager.nix  # NixOS home config
└── darwin/          # macOS-specific configuration
```

### Host Configuration
- **hosts/nixos/default.nix**: Main system configuration with VM detection
- **hosts/nixos/hardware-configuration.nix**: Auto-generated hardware config (UUIDs, filesystems)

## Key Patterns

### VM Detection and Optimization
The configuration automatically detects VMs and adjusts:
- Services (media servers disabled in VMs)
- Network configuration (DHCP vs static)
- Performance tuning (different sysctl parameters)
- Storage drivers (virtio vs hardware)

### Filesystem Management
- Uses UUID-based mounting (not partition labels)
- Hardware configuration must be generated during installation
- Disko has been removed due to conflicts

### Service Architecture
Services are conditionally enabled based on VM detection:
```nix
jellyfin = {
  enable = !isVM;
  openFirewall = !isVM;
};
```

### Secret Management
- Uses agenix for encrypted secrets
- Keys stored in private git repository
- SSH keys managed declaratively

## Critical Configuration Details

### Boot Issues Prevention
The installation scripts now prevent common boot failures:

**Previous Issue**: "waiting for /dev/disk/by-partlabel/disk-main-root"
- **Root Cause**: Disko expecting partition labels while system uses UUIDs
- **Solution Applied**: Removed disko, implemented robust UUID-based partitioning

**Current Safeguards**:
1. Hardware config always generated with UUIDs, never partition labels
2. Multiple validation checks prevent configuration errors
3. EFI bootloader installation verification
4. Flake syntax validation before installation

### Network Configuration
- Bare metal: Static IP on Intel X710 interfaces
- VMs: DHCP via NetworkManager
- Bridge configuration for virtualization

### Gaming and Performance
- NVIDIA drivers with modesetting enabled
- PipeWire with low-latency configuration
- Steam with Proton and GameMode
- nix-gaming flake for enhanced gaming packages

## Testing

### Local Testing Script
`scripts/test-local.sh` runs:
- Nix syntax checks
- Flake evaluation
- NixOS configuration builds
- Code formatting (nixpkgs-fmt)
- Static analysis (statix)
- VM integration tests

### VM Integration Tests
Located in `tests/vm-integration.nix`:
- Validates service startup
- Checks configuration correctness
- Tests network connectivity
- Verifies package installation

## Common Tasks

### Adding a Package
1. Edit `modules/nixos/packages.nix` or `modules/shared/packages.nix`
2. Run `./scripts/test-local.sh`
3. Apply with `nix run .#build-switch`

### Modifying Services
1. Edit `hosts/nixos/default.nix`
2. Consider VM detection logic
3. Test and apply changes

### Updating Dependencies
```bash
nix flake update
./scripts/test-local.sh
nix run .#build-switch
```

## Important Notes

- Never manually edit hardware-configuration.nix (regenerate with nixos-generate-config)
- VM detection happens at evaluation time using /sys filesystem
- High-performance optimizations only apply to bare metal
- All install scripts automatically generate hardware configuration
- Overlays in `overlays/` directory are auto-loaded