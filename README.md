# 🚀 Simple NixOS Configuration

**Simplified | XFS | GPT | 3 Profiles**

## Overview

A simplified NixOS configuration with just 3 profiles:
- **vm** - Virtual machine optimized
- **workstation** - Desktop with KDE Plasma 6, gaming, development
- **server** - Headless server with security hardening

Features:
- Always uses GPT partitioning
- XFS root filesystem
- 1GB EFI partition
- Hardware detection built into each profile

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Testing](#testing)
- [Development](#development)
- [Migration from v1](#migration-from-v1)
- [Support](#support)
- [Philosophy](#philosophy)
- [Testimonials](#testimonials)
- [Videos](#videos)
  - [macOS](#macos)
  - [NixOS](#nixos)
- [Disclaimer](#disclaimer)
- [Layout](#layout)
- [Installing](#installing)
  - [For macOS (May 2025)](#for-macos-may-2025)
  - [For NixOS](#for-nixos)
- [How to Create Secrets](#how-to-create-secrets)
- [Making Changes](#making-changes)
- [Compatibility and Feedback](#compatibility-and-feedback)
- [Appendix](#appendix)
  - [Why Nix Flakes](#why-nix-flakes)
  - [NixOS Components](#nixos-components)
  - [License](#license)
  - [Stars](#stars)

## Quick Start

### Installation
```bash
# Interactive menu (recommended)
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install

# Direct installation
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-vm
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-workstation
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-server
```

### Post-Installation Setup (Optional)
```bash
# Run post-installation setup for additional configuration
nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#post-install vm
nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#post-install workstation  
nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#post-install server
```

### Available Configurations

| Configuration | Description                              |
|---------------|------------------------------------------|
| vm           | Virtual machine optimized                |
| workstation  | Desktop with KDE Plasma 6, gaming, dev  |
| server       | Headless server with security hardening |
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

## Testing

### 🧪 Test-Driven Development Pipeline

This repository includes a comprehensive automated testing pipeline designed for TDD workflows:

- **VM-based testing**: Full integration testing using virtual machines
- **Snapshot/restore capabilities**: Clean state testing with VM snapshots
- **Comprehensive test coverage**: Syntax, build, installation, and integration tests
- **TDD workflow automation**: RED-GREEN-REFACTOR cycle support

### Test Status ✅

All configurations successfully pass automated testing:

- **✅ VM Configuration**: Builds and deploys successfully
- **✅ Workstation Configuration**: Builds with gaming and development modules  
- **✅ Server Configuration**: Builds with security and media server modules
- **✅ Module Integration**: All modules tested and functional
- **✅ Syntax Validation**: All Nix files syntactically correct

### Quick Testing

```bash
# Run all tests
./tests/test-runner.sh run full

# Run specific test suites
./tests/test-runner.sh run syntax      # Syntax validation
./tests/test-runner.sh run build       # Configuration building  
./tests/test-runner.sh run install     # Installation testing
./tests/test-runner.sh run integration # Module functionality

# TDD workflow
./tests/tdd-workflow.sh cycle          # Complete TDD cycle
./tests/tdd-workflow.sh watch          # Auto-test on changes
```

See the [tests README](tests/README.md) for comprehensive testing documentation.

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

### Overview
The new streamlined architecture eliminates the major pain points of the current configuration:

- ❌ **No more template drift** - Single flake, multiple profiles
- ❌ **No more runtime detection** - Explicit hardware declaration
- ❌ **No more UUID confusion** - Predictable filesystem labels
- ❌ **No more boot failures** - Rock-solid installation process

### New Structure

```
nixos-config/
├── flake-v2.nix           # New streamlined flake
├── profiles/              # Use-case profiles
│   ├── base.nix          # Universal foundation
│   ├── minimal.nix       # Bare essentials
│   ├── vm.nix           # VM optimizations
│   ├── workstation.nix  # Desktop + gaming
│   └── server.nix       # Headless server
├── hardware/             # Hardware profiles
│   ├── vm-qemu.nix      # QEMU VM hardware
│   └── generic-uefi.nix # Physical UEFI machines
└── install/
    └── install.sh       # Bulletproof installer
```

### Available Configurations

| Configuration    | Hardware      | Profile     | Use Case                    |
|-----------------|---------------|-------------|-----------------------------|
| `vm-minimal`    | vm-qemu       | minimal     | Minimal VM for testing     |
| `vm-workstation`| vm-qemu       | workstation | VM with full desktop       |
| `vm-server`     | vm-qemu       | server      | VM for server workloads    |
| `workstation`   | generic-uefi  | workstation | Physical desktop machine   |
| `server`        | generic-uefi  | server      | Physical server machine    |
| `minimal`       | generic-uefi  | minimal     | Minimal physical install   |

### Key Improvements

#### 1. **Predictable Filesystem Layout**
```nix
# Always uses labels, never UUIDs
fileSystems."/".device = "/dev/disk/by-label/nixos";
fileSystems."/".fsType = "ext4";

fileSystems."/boot".device = "/dev/disk/by-label/boot";
fileSystems."/boot".fsType = "vfat";
```

#### 2. **Layered Profile System**
```
Layer 1: base.nix         (universal foundation)
Layer 2: hardware/*.nix   (explicit hardware)
Layer 3: profile/*.nix    (use case: workstation/server/minimal)
Layer 4: vm.nix          (VM optimizations, if VM config)
Layer 5: home-manager    (user configuration)
```

#### 3. **Zero Runtime Detection**
- No filesystem probing
- No hardware detection at boot
- Everything declared explicitly
- Deterministic behavior

#### 4. **Bulletproof Installation**
```bash
# Interactive selection
nix run github:anthonymoon/nixos-config#install

# Direct installation
nix run github:anthonymoon/nixos-config#install vm-workstation

# Quick VM setup  
nix run github:anthonymoon/nixos-config#install-vm
```

### Migration Process

#### Phase 1: Validate New Structure
```bash
# Test configuration builds
cd test-v2
nix build .#nixosConfigurations.vm-minimal.config.system.build.toplevel
nix build .#nixosConfigurations.workstation.config.system.build.toplevel
```

#### Phase 2: Replace Main Flake
```bash
# Backup current
mv flake.nix flake-old.nix

# Activate new structure
mv flake-v2.nix flake.nix
```

#### Phase 3: Test Installation
```bash
# Test VM installation
sudo nix run .#install vm-minimal

# Test on physical hardware
sudo nix run .#install workstation
```

#### Phase 4: Clean Up Legacy
```bash
# Remove old structure
rm -rf templates/ apps/ hosts/ modules/
rm flake-old.nix
```

### Benefits

#### For Users
- **Simpler installation** - Clear menu, predictable process
- **No boot failures** - Filesystem labels eliminate UUID issues
- **Faster setup** - No template selection confusion

#### For Maintainers  
- **Single source of truth** - No template drift
- **Easier testing** - Build any config with `nix build`
- **Clear architecture** - Explicit layers, no magic detection
- **Reduced complexity** - 50% fewer files, clearer structure

#### For Development
- **Reproducible builds** - No runtime dependencies
- **Easy customization** - Override any layer explicitly
- **Better debugging** - No hidden detection logic
- **Modular design** - Mix and match profiles/hardware

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

## Branch Protection Configuration

This document outlines the required branch protection rules for the NixOS configuration repository.

## Branch Protection Rules

### Main Branch (Production)
**Branch:** `main`

**Settings:**
- ✅ Restrict pushes that create files larger than 100MB
- ✅ Require a pull request before merging
  - ✅ Require approvals: **2** (minimum)
  - ✅ Dismiss stale PR approvals when new commits are pushed
  - ✅ Require review from code owners
  - ✅ Restrict approvals to users with write access
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - **Required status checks:**
    - `validate / Validate Configuration`
    - `integration-tests / Integration Tests`
    - `load-tests / Load Tests`
    - `approval-gate / Manual Approval Required`
- ✅ Require conversation resolution before merging
- ✅ Require signed commits
- ✅ Require linear history
- ✅ Include administrators (enforce for admins too)
- ✅ Restrict force pushes
- ✅ Allow deletions: **NO**

### Staging Branch
**Branch:** `staging`

**Settings:**
- ✅ Restrict pushes that create files larger than 100MB
- ✅ Require a pull request before merging (only for PRs to main)
- ✅ Require status checks to pass before merging
  - **Required status checks:**
    - `pre-flight / Pre-flight Checks`
    - `integration-tests / Integration Tests`
- ✅ Require signed commits
- ✅ Restrict force pushes from non-admins
- ✅ Allow deletions: **YES** (for branch management)

### Dev Branch
**Branch:** `dev`

**Settings:**
- ✅ Restrict pushes that create files larger than 100MB
- ✅ Require status checks to pass before merging
  - **Required status checks:**
    - `validate / Pre-deployment Validation`
    - `smoke-tests / Smoke Tests`
- ✅ Allow force pushes from admins
- ✅ Allow deletions: **YES**

## Required Secrets

Configure the following repository secrets:

### SSH Keys
- `DEV_VM_SSH_KEY` - SSH private key for dev VM access
- `STAGING_VM_SSH_KEY` - SSH private key for staging VM access  
- `PRODUCTION_SSH_KEY` - SSH private key for production bare metal access

### Optional Integration Secrets
- `CACHIX_AUTH_TOKEN` - Cachix authentication token (for faster builds)
- `SLACK_WEBHOOK_URL` - Slack webhook for deployment notifications

## Environment Protection Rules

### Production Environment
**Environment:** `production`

**Settings:**
- ✅ Required reviewers: **2** (minimum)
- ✅ Wait timer: **5 minutes** (cooling-off period)
- ✅ Deployment protection rules:
  - Only deploy from `main` branch
  - Require passing status checks
  - Require manual approval

### Production Approval Environment  
**Environment:** `production-approval`

**Settings:**
- ✅ Required reviewers: **1** (senior team member)
- ✅ Deployment protection rules:
  - Only allow specific users/teams to approve
  - Require all status checks to pass

## Workflow Files Security

Ensure workflow files have proper permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  actions: read
  checks: write
```

## Code Owners File

Create `.github/CODEOWNERS`:

```
# Global ownership
* @your-username

# Critical configuration files
/hosts/nixos/default.nix @senior-team-member @infrastructure-team
/flake.nix @senior-team-member
/.github/workflows/ @devops-team @senior-team-member

# Security-sensitive files
/modules/*/security/ @security-team @senior-team-member
```

## Auto-merge Configuration

For automated dependency updates, configure auto-merge rules:

1. Create a separate workflow for dependency PRs
2. Allow auto-merge only for:
   - Minor version updates
   - Security patches
   - After all checks pass
   - With specific labels (e.g., `dependencies`, `auto-merge`)

## Manual Setup Instructions

### 1. Configure Branch Protection (GitHub UI)

1. Go to **Settings** → **Branches**
2. Add rules for each branch using settings above
3. Ensure "Include administrators" is checked for main branch

### 2. Create Environments (GitHub UI)

1. Go to **Settings** → **Environments**
2. Create `production` and `production-approval` environments
3. Configure protection rules as specified above

### 3. Add Repository Secrets (GitHub UI)

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add all required secrets listed above
3. Ensure secrets are properly scoped to environments

### 4. Set Up Code Owners

1. Create `.github/CODEOWNERS` file with appropriate team assignments
2. Update teams/usernames to match your organization

### 5. Enable Security Features

1. Go to **Settings** → **Security**
2. Enable:
   - Dependency graph
   - Dependabot alerts
   - Dependabot security updates
   - Secret scanning
   - Code scanning (if available)

## Testing the Setup

After configuration, test the workflow:

1. Create a feature branch
2. Make a small change
3. Push to `dev` branch
4. Verify dev deployment workflow runs
5. Check that staging promotion happens automatically
6. Create PR from staging to main
7. Verify all required checks run
8. Test manual approval process

The branch protection is now configured for safe, automated NixOS deployments!

## CLAUDE.md

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

## NixOS Configuration Refactor Plan

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
  fileSystems."/".device = "/dev/disk/by-label/nixos";
  fileSystems."/".fsType = "ext4";
  
  fileSystems."/boot".device = "/dev/disk/by-label/boot";
  fileSystems."/boot".fsType = "vfat";
  
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

## Overlays

Files in this directory run automatically as part of each build. Some common ways I've used overlays in the past:
* Applying patches
* Downloading different versions of files (locking to a version or trying a fork)
* Workarounds and stuff I need to run temporarily

Here are some previous examples.

### Overriding a package with a specific hash from Github
To get the sha256, I just made something up and tried to build it; Nix will complain with the actual sha256.
```nix
final: prev: {
  picom = prev.picom.overrideAttrs (old: {
    src = prev.fetchFromGitHub {
      owner = "pijulius";
      repo = "picom";
      rev = "982bb43e5d4116f1a37a0bde01c9bda0b88705b9";
      sha256 = "YiuLScDV9UfgI1MiYRtjgRkJ0VuA1TExATA2nJSJMhM=";
    };
  });
}
```

### Override a file or attribute of a package
In Nix, we get to just patch things willy nilly. This is an old patch I used to get the `cypress` package working; it tidied me over until a proper fix was in `nixpkgs`.

```nix
# When Cypress starts, it copies some files locally from the Nix Store, but
# fails to remove the read-only flag.
#
# Luckily, the code responsible is a plain text script that we can easily patch:
#
final: prev: {
  cypress = prev.cypress.overrideAttrs (oldAttrs: {
    installPhase = let
      matchForChrome = "yield utils_1.default.copyExtension(pathToExtension, extensionDest);";
      appendForChrome = "yield fs_1.fs.chmodAsync(extensionBg, 0o0644);"; # We edit this line

      matchForFirefox = "copyExtension(pathToExtension, extensionDest)";
      replaceForFirefox = "copyExtension(pathToExtension, extensionDest).then(() => fs.chmodAsync(extensionBg, 0o0644))"; # We edit this line
    in ''
      sed -i '/${matchForChrome}a\${appendForChrome}' \
          ./resources/app/packages/server/lib/browsers/chrome.js

      sed -i 's/${matchForFirefox}/${replaceForFirefox}/' \
          ./resources/app/packages/server/lib/browsers/utils.js
    '' + oldAttrs.installPhase;
  });
}
```