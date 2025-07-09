# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a NixOS configuration repository using flakes for declarative infrastructure as code. The system follows a modular composition pattern with layered specialization:

- **common.nix**: Universal settings (users, SSH, firewall)
- **base.nix**: Foundation layer (boot, networking, packages)
- **profiles/**: Role-specific configurations (vm, workstation, server, iso)
- **modules/**: Optional feature modules (gaming, development, media-server, security)

## Common Development Commands

### Building and Testing
```bash
# Build a specific profile
nix build .#vm --no-write-lock-file --extra-experimental-features 'nix-command flakes'
nix build .#workstation --no-write-lock-file --extra-experimental-features 'nix-command flakes'
nix build .#server --no-write-lock-file --extra-experimental-features 'nix-command flakes'

# Build ISO image
nix run .#build-iso --no-write-lock-file --extra-experimental-features 'nix-command flakes'

# Enter development shell
nix develop --no-write-lock-file --extra-experimental-features 'nix-command flakes'
```

### Installation
```bash
# Install a configuration
nix run .#install <profile> --no-write-lock-file --extra-experimental-features 'nix-command flakes'

# Use disko for disk partitioning
nix run .#disko --no-write-lock-file --extra-experimental-features 'nix-command flakes'
```

### System Management
```bash
# Rebuild system (on target machine)
nixos-rebuild switch --flake .#<profile> --no-write-lock-file --extra-experimental-features 'nix-command flakes'

# Test configuration without switching
nixos-rebuild test --flake .#<profile> --no-write-lock-file --extra-experimental-features 'nix-command flakes'
```

## Configuration Structure

### Core Components

1. **flake.nix**: Central orchestrator defining inputs, outputs, and system configurations
2. **lib/default.nix**: Contains `mkSystem` factory function that standardizes system creation
3. **disko-config.nix**: Declarative disk partitioning with BTRFS subvolumes

### Profile Hierarchy
```
common.nix (Universal: users, SSH, firewall settings)
    ↓
base.nix (Foundation: boot, network, packages)
    ↓
┌─────────┴─────────┬──────────────┬─────────────┐
vm.nix           workstation.nix   server.nix    iso.nix
[minimal]        [desktop+dev]     [hardened]    [installer]
```

### Module System
Feature modules are self-contained with enable flags:
- `modules.gaming.enable = true` - Steam, Wine, gaming tools
- `modules.development.enable = true` - Dev tools, languages, databases
- `modules.media-server.enable = true` - Sonarr, Radarr, Jellyfin stack
- `modules.security.enable = true` - Fail2ban, hardening, monitoring

## Mandatory Rules

### System Configuration
- **Rolling Release**: Use `nixos-unstable`, no lock files
- **Nix Commands**: Always use `--no-write-lock-file --extra-experimental-features 'nix-command flakes'`
- **Firewall**: Must be disabled (`networking.firewall.enable = false`)
- **Installation**: Must be non-interactive, auto-confirm prompts

### User & SSH Management
- **Standard Users**: `root`, `nixos`, and `amoon` must exist on all profiles
- **SSH Key**: Add this key to all users' authorized_keys:
  ```
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us
  ```
- **SSH Service**: Enable OpenSSH with passwordless root login

### Development Workflow
- **Nix DSL First**: Prefer Nix language over shell scripts
- **Local Verification**: Build locally before committing (`nix build .#<profile>`)

### Remote Testing
When testing on remote systems (e.g., nixos@10.10.10.180):
1. Use the personal SSH key for authentication: `ssh -i ~/.ssh/id_ed25519_personal_20240523 nixos@10.10.10.180`
2. Copy the repository to the remote system: `scp -i ~/.ssh/id_ed25519_personal_20240523 -r /home/amoon/nixos-config nixos@10.10.10.180:/home/nixos/`
3. SSH into the remote system and run commands from the copied repository directory

### Package Validation Workflow
Before adding packages to configurations, always validate package names:
1. Install nix-search-cli: `yay -S nix-search-cli`
2. Before adding any package to a configuration, verify it exists: `nix-search-cli <package-name>`
3. Use exact package names as returned by nix-search-cli
4. This prevents build failures due to invalid package names

## Disk Layout (BTRFS)
```
GPT Partition Table
├── EFI System Partition (1GB, FAT32)
└── BTRFS Root Partition (remaining)
    ├── @ (root subvolume)
    ├── @home
    ├── @nix
    ├── @log
    └── @snapshots
```

## Key Files and Functions

- **lib/default.nix:25**: `mkSystem` function - factory for creating NixOS configurations
- **modules/common.nix**: Universal user and SSH configuration
- **profiles/base.nix**: Foundation configuration applied to all systems
- **flake.nix:28**: `nixosConfigurations` - maps profile names to system configs
- **disko-config.nix**: Declarative disk partitioning configuration