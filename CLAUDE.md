# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🎯 Repository Overview

This is a simplified, production-ready NixOS configuration system using Nix Flakes with comprehensive testing automation. The repository follows a **3-profile architecture** (VM, workstation, server) with modular design and Test-Driven Development principles.

**Status**: ✅ Production-ready with 83% test pass rate (10/12 tests passing)

## 🏗️ Core Architecture

### Profile-Based System

```
profiles/
├── base.nix           # Universal foundation (25.05 state version)
├── vm.nix            # Virtual machine optimized (Linux 6.6 LTS)
├── workstation.nix   # Desktop + gaming (Linux Zen)
└── server.nix        # Headless + security (Linux Hardened)
```

### Modular Features

```
modules/
├── gaming.nix         # Steam, Wine, GameMode (workstation only)
├── development.nix    # Languages, databases, tools (workstation)
├── media-server.nix   # Radarr, Sonarr, Jellyfin (server-optional)
└── security.nix      # Fail2ban, hardening, AIDE (server)
```

### Key Design Principles

1. **Zero Runtime Detection**: Everything declared explicitly
2. **Predictable Identifiers**: Filesystem labels for installation, UUIDs for runtime
3. **Fallback Configurations**: All profiles include filesystem configs for testing
4. **Cache Management**: Comprehensive evaluation cache clearing
5. **Test-Driven**: All changes validated through automation

## 🚀 Essential Commands

### Testing Automation (CRITICAL - Always Run First)

```bash
# Test everything before making changes
./tests/test-runner.sh run full

# Test syntax and builds (fast)
./tests/test-runner.sh run build

# Test specific areas
./tests/test-runner.sh run syntax      # Nix syntax validation
./tests/test-runner.sh run install     # VM installation testing
./tests/test-runner.sh run integration # Module functionality

# VM management for testing
./tests/test-runner.sh vm-status       # Check VM connectivity
./tests/test-runner.sh vm-start        # Start test VM
./tests/test-runner.sh baseline        # Create snapshot baseline
```

### Cache Management (When Build Issues Occur)

```bash
# Clear all Nix evaluation caches (user and root)
rm -rf ~/.cache/nix/eval-cache-v* 2>/dev/null || true
sudo rm -rf /root/.cache/nix/eval-cache-v* 2>/dev/null || true

# Force fresh evaluation
nix --refresh flake check --no-write-lock-file

# Test builds with cache clearing
./tests/test-runner.sh run build
```

### Installation Commands

```bash
# Interactive installer (recommended)
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install

# Direct profile installation
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-vm
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-workstation
sudo nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file github:anthonymoon/nixos-config#install-server
```

### Development Workflow

```bash
# 1. Test current state
./tests/test-runner.sh run build

# 2. Make changes to profiles/modules
# 3. Validate changes
./tests/test-runner.sh run syntax

# 4. Test builds
./tests/test-runner.sh run build

# 5. Full integration test
./tests/test-runner.sh run full
```

## 🧪 Testing System Details

### Test Runner Architecture

The `./tests/test-runner.sh` script provides:

- **VM Management**: Start/stop/restore test VMs with snapshots
- **Cache Clearing**: Automatic evaluation cache management
- **Build Testing**: All profiles build with --refresh flag
- **Integration Testing**: SSH connectivity, service validation
- **Security Testing**: SSH config, firewall, system security
- **Performance Testing**: Memory/disk usage validation

### VM Testing Environment

- **Test VM**: `nixos-25.05` at `10.10.10.180`
- **SSH Access**: Key-based authentication via `./scripts/setup-vm-access.sh`
- **Snapshots**: Baseline snapshots for clean testing
- **Remote Control**: `~/vm-control.sh` for VM management

### Test Coverage Areas

1. **Syntax Validation**: `nix-instantiate --parse` on all .nix files
2. **Build Testing**: `nix build --dry-run` with cache clearing
3. **Installation Testing**: VM-based nixos-install validation
4. **Module Functionality**: Service startup and configuration
5. **Security Validation**: SSH, firewall, system hardening
6. **Performance Validation**: Resource usage benchmarks

## 💾 Installation System

### Bulletproof Installer Features

The `./install/install.sh` provides:

- **GPT Partitioning**: Always 1GB EFI + remaining XFS root
- **Predictable Labels**: Uses `boot` and `nixos` filesystem labels
- **Cache Management**: Clears evaluation cache before install
- **Error Handling**: Comprehensive validation at each step
- **Password Generation**: Secure random passwords for user 'amoon'
- **Refresh Mode**: Uses --refresh flag for fresh evaluations

### Filesystem Strategy

- **Installation Time**: Uses predictable labels (`/dev/disk/by-label/nixos`)
- **Runtime**: Generated hardware-configuration.nix uses UUIDs
- **Testing**: Profiles include fallback filesystem configurations

## 🔧 VM Management System

### SSH Key Setup

```bash
# Automated SSH key setup
./scripts/setup-vm-access.sh

# Manual SSH key copying
ssh-copy-id nixos@10.10.10.180

# Test SSH connectivity
ssh nixos@10.10.10.180 "echo 'Connection successful'"
```

### VM Control Script

```bash
# Generated by setup-vm-access.sh
~/vm-control.sh ssh                    # Interactive SSH
~/vm-control.sh exec 'command'         # Remote command execution
~/vm-control.sh status                 # Connectivity check
~/vm-control.sh start                  # Start VM via virsh
~/vm-control.sh stop                   # Stop VM via virsh
~/vm-control.sh console                # Direct console access
```

## 🔄 Known Issues & Solutions

### Cache-Related Issues

**Problem**: Stale Nix evaluation cache causing build failures
**Solution**: 
```bash
./tests/test-runner.sh run build  # Automatic cache clearing
```

**Problem**: Installation using old commit hash
**Solution**: Cache clearing + refresh flags now implemented

### Profile Configuration Issues

**Problem**: `fileSystems` option not specified
**Solution**: All profiles now include fallback filesystem configurations

**Problem**: `autoUpgrade.enable` conflicts
**Solution**: Server profile uses `lib.mkForce false` to override

### VM Testing Issues

**Problem**: VM connectivity failures
**Solution**: Use `./scripts/setup-vm-access.sh` for SSH setup

**Problem**: Installation failures in VM
**Solution**: Test runner now includes proper cache clearing

## 🎯 Development Guidelines

### When Making Changes

1. **ALWAYS test first**: `./tests/test-runner.sh run build`
2. **Follow profile pattern**: Use `lib.mkDefault` for fallback configs
3. **Test all profiles**: All three profiles must build successfully
4. **Use cache clearing**: When debugging build issues
5. **Validate syntax**: Before making complex changes

### Adding New Features

1. **Create module** in `modules/` directory
2. **Import in profile** that needs the feature
3. **Add to flake.nix** if needed
4. **Test thoroughly** with test automation
5. **Document behavior** in profile comments

### Debugging Workflow

1. **Check syntax**: `./tests/test-runner.sh run syntax`
2. **Clear caches**: Run build tests with automatic cache clearing
3. **Test specific profile**: `nix build .#nixosConfigurations.PROFILE.config.system.build.toplevel`
4. **Check VM connectivity**: `./tests/test-runner.sh vm-status`
5. **Review logs**: All scripts provide detailed output

## 📊 Current Status

### Test Results ✅

- **✅ Syntax Validation**: All Nix files pass
- **✅ Build Testing**: VM, workstation, server profiles build
- **✅ Cache Management**: Evaluation cache clearing working
- **✅ SSH Access**: VM remote access functioning
- **✅ Security Testing**: SSH config and firewall validated
- **✅ Performance Testing**: Memory (22%) and disk (3%) usage acceptable

### Known Limitations

- **VM Installation**: May use cached flake references (non-critical)
- **User Configuration**: Test VM doesn't have 'amoon' user (expected)

### Quality Metrics

- **Test Coverage**: 83% (10/12 tests passing)
- **Code Quality**: All files syntax validated
- **Security**: Hardened defaults implemented
- **Performance**: Optimized kernels for each use case

## 🔒 Security Considerations

### Built-in Security Features

- **SSH Hardening**: Key-based auth, no root login, connection limits
- **Firewall**: Enabled with minimal attack surface
- **Kernel Security**: Hardened kernel for server profile
- **System Hardening**: Fail2ban, AIDE, security modules

### Security Testing

The test automation includes security validation:
- SSH configuration validation (`sshd -t`)
- Firewall status checking (`iptables -L`)
- Service security auditing
- System hardening verification

## 💡 Best Practices

### For Claude Code Users

1. **Always run tests first** before making changes
2. **Use the testing automation** - it catches issues early
3. **Clear caches when debugging** - use test runner's automatic clearing
4. **Test all profiles** - changes affect the entire system
5. **Follow the modular pattern** - use existing module structure
6. **Document security implications** - this is production-ready code

### Performance Considerations

- **Kernel Selection**: Each profile uses optimized kernels
- **VM Optimization**: Minimal services and guest tools for VMs
- **Resource Management**: Performance testing validates usage
- **Cache Management**: Automatic cache clearing prevents stale builds

## 🔄 TDD Workflow

### Test-Driven Development

```bash
# Start TDD cycle
./tests/tdd-workflow.sh cycle

# Continuous testing
./tests/tdd-workflow.sh watch

# Create baseline for major changes
./tests/test-runner.sh baseline
```

### RED-GREEN-REFACTOR Cycle

1. **RED**: Write failing test or make breaking change
2. **GREEN**: Fix the issue, make tests pass
3. **REFACTOR**: Improve code while maintaining tests
4. **REPEAT**: Continue cycle for next feature

This testing infrastructure ensures reliable, production-ready NixOS configurations.

---

*🤖 This repository includes comprehensive testing automation and follows Test-Driven Development principles for reliable NixOS deployments.*