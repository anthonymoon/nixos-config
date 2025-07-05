# 🚀 Bulletproof NixOS Configuration v2.0

**Zero-Failure Architecture | Profile-Based | No Runtime Detection**

## Quick Start

### Installation
```bash
# Interactive menu (recommended)
sudo nix run github:anthonymoon/nixos-config#install

# Direct installation
sudo nix run github:anthonymoon/nixos-config#install vm-workstation
sudo nix run github:anthonymoon/nixos-config#install workstation
```

### Available Configurations

| Configuration    | Hardware      | Profile     | Description                    |
|-----------------|---------------|-------------|--------------------------------|
| `vm-minimal`    | QEMU VM       | Minimal     | Minimal VM (SSH only)         |
| `vm-workstation`| QEMU VM       | Workstation | VM with KDE + gaming + dev     |
| `vm-server`     | QEMU VM       | Server      | VM for server workloads       |
| `workstation`   | Physical UEFI | Workstation | Desktop + gaming + development |
| `server`        | Physical UEFI | Server      | Headless server services      |
| `minimal`       | Physical UEFI | Minimal     | Minimal physical install      |

## Architecture

### Zero-Failure Design
- ✅ **Predictable filesystem labels** (`boot`, `nixos`) - never UUIDs
- ✅ **No runtime detection** - everything declared explicitly  
- ✅ **Profile composition** - mix and match hardware + use cases
- ✅ **Single installer** - bulletproof partitioning and setup
- ✅ **Layer-based** - clear separation of concerns

### Layered Profile System
```
Layer 1: profiles/base.nix          # Universal foundation
Layer 2: hardware/{vm-qemu,generic-uefi}.nix  # Hardware declaration  
Layer 3: profiles/{minimal,workstation,server}.nix  # Use case
Layer 4: profiles/vm.nix            # VM optimizations (if VM)
Layer 5: home-manager               # User configuration
```

### Directory Structure
```
nixos-config/
├── flake.nix           # Streamlined flake with 6 configurations
├── profiles/           # Use-case profiles
│   ├── base.nix       # Universal foundation (users, packages, nix)
│   ├── minimal.nix    # Bare essentials only
│   ├── vm.nix         # VM optimizations
│   ├── workstation.nix # KDE + gaming + development
│   └── server.nix     # Headless server services
├── hardware/          # Hardware profiles (explicit declaration)
│   ├── vm-qemu.nix    # QEMU VM hardware
│   └── generic-uefi.nix # Physical UEFI machines
└── install/
    └── install.sh     # Bulletproof installer
```

## Key Features

### Bulletproof Installation
- **Predictable partitioning**: Always creates `boot` and `nixos` labels
- **Zero UUID confusion**: Uses filesystem labels, not discovery
- **Comprehensive validation**: Checks every step
- **Interactive menu**: Clear configuration selection
- **No template complexity**: Single installer for everything

### Profile-Based Configuration
- **Workstation**: KDE Plasma 6, gaming (Steam, Lutris), development tools
- **Server**: Docker, monitoring tools, SSH hardening, performance tuning
- **Minimal**: Just SSH and essential tools
- **VM**: Optimized for virtual machines (spice, guest tools, fast boot)

### Zero Runtime Detection
- **No filesystem probing** - hardware declared explicitly
- **No VM detection** - use vm-* configurations for VMs
- **No conditional logic** - everything predictable
- **Deterministic behavior** - same input = same output

## Development

### Testing Configurations
```bash
# Build any configuration
nix build .#nixosConfigurations.vm-workstation.config.system.build.toplevel

# Test installer locally
sudo ./install/install.sh vm-minimal

# Development shell
nix develop
```

### Adding New Profiles
1. Create `profiles/myprofile.nix`
2. Add to `flake.nix` configurations
3. Test with `nix build`

### Custom Hardware
1. Create `hardware/myhardware.nix`
2. Add filesystem declarations
3. Update `flake.nix` with new combinations

## Migration from v1

The v2 architecture eliminates all v1 pain points:

| v1 Issues | v2 Solutions |
|-----------|-------------|
| ❌ Template drift | ✅ Single flake, profile composition |
| ❌ Runtime VM detection | ✅ Explicit vm-* configurations |
| ❌ UUID/label confusion | ✅ Predictable filesystem labels |
| ❌ Complex install scripts | ✅ Single bulletproof installer |
| ❌ Boot failures | ✅ Zero-failure architecture |

## Support

- **Installation issues**: Check that `/dev/vda` exists and is the target disk
- **Boot failures**: Ensure using v2 installer (creates proper labels)
- **Configuration errors**: Each profile is self-contained and bootable
- **Development**: Use `nix develop` for testing environment

## Philosophy

This configuration follows the **"Explicit over Implicit"** principle:
- Declare hardware explicitly instead of detecting at runtime
- Use predictable identifiers instead of discovered UUIDs
- Compose profiles instead of conditional logic
- Fail fast and clearly instead of silent failures

**Result**: A NixOS configuration that is impossible to break and trivial to understand.