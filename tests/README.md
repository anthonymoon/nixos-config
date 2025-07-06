# Automated Test-Driven Development Pipeline

This directory contains a comprehensive automated testing pipeline for the NixOS configuration, leveraging VM snapshot/restore capabilities for true integration testing.

## 🎯 Test Philosophy

Our testing approach follows **Test-Driven Development (TDD)** principles:

1. **RED**: Write failing tests that define expected behavior
2. **GREEN**: Implement minimal code to make tests pass
3. **REFACTOR**: Improve code quality while keeping tests green

## 🧪 Test Components

### Core Test Runner (`test-runner.sh`)
The main test automation framework with VM management capabilities.

**Features:**
- VM snapshot creation and restoration
- Comprehensive test suites (syntax, build, integration)
- Automated connectivity testing
- Performance monitoring
- Test result reporting

**Usage:**
```bash
# Create baseline snapshot for testing
./tests/test-runner.sh baseline

# Run specific test suites
./tests/test-runner.sh run syntax      # Syntax validation
./tests/test-runner.sh run build       # Configuration building
./tests/test-runner.sh run install     # Installation testing
./tests/test-runner.sh run integration # Module functionality
./tests/test-runner.sh run full        # Complete test suite

# VM management
./tests/test-runner.sh vm-start        # Start test VM
./tests/test-runner.sh vm-restore      # Restore to clean state
./tests/test-runner.sh vm-status       # Check VM status
```

### Module Integration Tests (`test-modules.sh`)
Specialized tests for individual modules and their interactions.

**Coverage:**
- Gaming module (Steam, Wine, GameMode)
- Development module (languages, databases, tools)
- Media server module (Radarr, Sonarr, Jellyfin)
- Security module (Fail2ban, hardening, monitoring)
- System integration (users, networking, filesystem)

**Usage:**
```bash
# Test specific modules
./tests/test-modules.sh gaming         # Gaming functionality
./tests/test-modules.sh development    # Development tools
./tests/test-modules.sh media-server   # Media stack
./tests/test-modules.sh security       # Security features
./tests/test-modules.sh system         # System integration
./tests/test-modules.sh all            # All modules
```

### TDD Workflow (`tdd-workflow.sh`)
Complete development workflow automation following TDD principles.

**Features:**
- Guided TDD cycle implementation
- Automated file watching and testing
- Feature development workflows
- Performance testing
- Integration with git workflows

**Usage:**
```bash
# TDD Cycle
./tests/tdd-workflow.sh red           # Write failing tests
./tests/tdd-workflow.sh green         # Implement solution
./tests/tdd-workflow.sh refactor      # Improve code quality
./tests/tdd-workflow.sh cycle         # Complete cycle

# Development Workflow
./tests/tdd-workflow.sh new <feature> # Start new feature
./tests/tdd-workflow.sh watch         # Auto-test on changes
./tests/tdd-workflow.sh commit <msg>  # Test and commit
./tests/tdd-workflow.sh integration   # Full integration test

# Performance
./tests/tdd-workflow.sh perf          # Performance testing
```

## 🔄 VM Testing Infrastructure

### Snapshot-Based Testing
The pipeline leverages VM snapshots for reliable, repeatable testing:

1. **Baseline Creation**: Clean VM state saved as `test-baseline`
2. **Test Execution**: Tests run against fresh VM instances
3. **State Restoration**: VM restored to baseline between test runs
4. **Isolation**: Each test suite runs in clean environment

### VM Management Commands
```bash
# VM lifecycle management
sudo virsh list --all                 # List all VMs
sudo virsh start nixos-25.05         # Start test VM
sudo virsh snapshot-create-as nixos-25.05 test-baseline "Clean state"
sudo virsh snapshot-revert nixos-25.05 test-baseline
sudo virsh snapshot-list nixos-25.05  # List snapshots
```

## 📋 Test Categories

### 1. Syntax Validation
- **Purpose**: Ensure all Nix files have valid syntax
- **Scope**: `flake.nix`, `profiles/*.nix`, `modules/*.nix`
- **Tools**: `nix-instantiate --parse`
- **Speed**: ⚡ Fast (< 5 seconds)

### 2. Build Testing
- **Purpose**: Verify configurations can be built
- **Scope**: All three configurations (vm, workstation, server)
- **Tools**: `nix build --dry-run`
- **Speed**: 🔶 Medium (10-30 seconds)

### 3. Installation Testing
- **Purpose**: Test complete installation process
- **Scope**: VM deployment and post-installation
- **Tools**: VM restoration + installation scripts
- **Speed**: 🔴 Slow (2-5 minutes)

### 4. Integration Testing
- **Purpose**: Verify module functionality and interactions
- **Scope**: Service status, configuration validation, connectivity
- **Tools**: SSH commands + service checks
- **Speed**: 🔶 Medium (30-60 seconds)

### 5. Security Testing
- **Purpose**: Validate security configurations
- **Scope**: Firewall, SSH, hardening parameters
- **Tools**: System command validation
- **Speed**: ⚡ Fast (10-15 seconds)

### 6. Performance Testing
- **Purpose**: Monitor build times and system performance
- **Scope**: Configuration build speed, VM responsiveness
- **Tools**: Time measurements + system monitoring
- **Speed**: 🔶 Medium (15-30 seconds)

## 🚀 Quick Start

### Initial Setup
```bash
# 1. Ensure VM is running
./tests/test-runner.sh vm-start

# 2. Create test baseline
./tests/test-runner.sh baseline

# 3. Run initial test suite
./tests/test-runner.sh run full
```

### Development Workflow
```bash
# 1. Start new feature development
./tests/tdd-workflow.sh new my-feature

# 2. Write failing tests (RED)
# Edit test files...
./tests/tdd-workflow.sh red

# 3. Implement feature (GREEN)
# Edit configuration files...
./tests/tdd-workflow.sh green

# 4. Refactor and improve (REFACTOR)
# Improve code quality...
./tests/tdd-workflow.sh refactor

# 5. Commit changes
./tests/tdd-workflow.sh commit "Add my-feature functionality"
```

### Continuous Testing
```bash
# Watch for file changes and auto-test
./tests/tdd-workflow.sh watch

# In another terminal, make changes and watch tests run automatically
```

## 📊 Test Reporting

### Test Results Format
```
════════════════════════════════════════
  Test Summary
════════════════════════════════════════
Total tests: 15
Passed: 14
Failed: 1
All tests passed! ✅
```

### Exit Codes
- `0`: All tests passed
- `1`: Some tests failed
- `2`: Test infrastructure error

### Logging
- **Green [PASS]**: Test succeeded
- **Red [FAIL]**: Test failed
- **Yellow [SKIP]**: Test skipped (feature not enabled)
- **Blue [TEST]**: Test starting
- **Purple [INFO]**: General information

## 🔧 Configuration

### Environment Variables
```bash
# VM Configuration
export TEST_VM_NAME="nixos-25.05"        # VM name in virsh
export TEST_VM_IP="10.10.10.180"         # VM IP address
export TEST_VM_USER="nixos"              # SSH username
export TEST_TIMEOUT=300                  # VM startup timeout

# Test Configuration
export TEST_SNAPSHOT_NAME="test-baseline" # Baseline snapshot name
```

### Prerequisites
- VM with SSH access configured
- virsh/libvirt access (sudo required)
- NixOS test VM accessible at configured IP
- SSH key authentication set up

## 🎯 Best Practices

### Test Writing Guidelines
1. **Atomic Tests**: Each test should test one specific behavior
2. **Descriptive Names**: Test names should clearly describe what they validate
3. **Fast Feedback**: Prefer quick tests over slow ones when possible
4. **Reliable**: Tests should be deterministic and not flaky
5. **Clean State**: Always start from clean VM state for integration tests

### Development Guidelines
1. **Red First**: Always write failing tests before implementation
2. **Minimal Green**: Implement just enough to make tests pass
3. **Refactor Safely**: Only refactor when tests are green
4. **Commit Often**: Commit after each successful TDD cycle
5. **Test Everything**: Every feature should have corresponding tests

### VM Management Guidelines
1. **Snapshot Early**: Create baseline snapshots before making changes
2. **Restore Often**: Use fresh VM state for each test run
3. **Clean Up**: Remove old snapshots to save disk space
4. **Monitor Resources**: Watch VM performance during testing
5. **Backup Critical**: Keep backups of important VM snapshots

## 🔍 Troubleshooting

### Common Issues

**VM Not Accessible**
```bash
# Check VM status
./tests/test-runner.sh vm-status

# Restart VM
./tests/test-runner.sh vm-stop
./tests/test-runner.sh vm-start
```

**Tests Timing Out**
```bash
# Increase timeout
export TEST_TIMEOUT=600

# Check VM performance
./tests/tdd-workflow.sh perf
```

**Snapshot Issues**
```bash
# List snapshots
./tests/test-runner.sh snapshots

# Recreate baseline
./tests/test-runner.sh baseline
```

**Build Failures**
```bash
# Check syntax first
./tests/test-runner.sh run syntax

# Test individual configurations
nix build --no-link --dry-run .#nixosConfigurations.vm.config.system.build.toplevel
```

This testing pipeline provides comprehensive coverage while maintaining simplicity and speed, enabling confident development and deployment of NixOS configurations.