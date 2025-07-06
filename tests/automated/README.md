# Automated Testing Framework

This directory contains the automated testing framework for NixOS configurations.

## Overview

The testing framework provides real-time monitoring and intelligent reaction to test execution, simulating an "agent-based" approach where the system can detect and respond to failures as they occur.

## Components

### 1. `vm-test-framework.sh`
Basic VM testing framework with QEMU management:
- VM lifecycle management (create, start, stop)
- SSH-based test execution
- Profile-specific test cases
- Simple pass/fail reporting

### 2. `streaming-test-runner.sh`
Advanced streaming test runner with libvirt integration:
- Real-time output stream processing
- Pattern matching for error detection
- State management and persistence
- Parallel test execution capability
- Detailed logging and reporting

### 3. `agent-monitor.py`
Sophisticated Python-based test agent:
- Asynchronous stream processing
- Intelligent pattern recognition
- "Agent thoughts" - decision making based on output
- Comprehensive event tracking
- Detailed failure analysis

## Usage

### Basic Testing
```bash
# Test a single profile
./vm-test-framework.sh test vm

# Test all profiles
./vm-test-framework.sh test all

# Start VM for manual testing
./vm-test-framework.sh start
```

### Advanced Testing with Streaming
```bash
# Test with real-time monitoring
./streaming-test-runner.sh test vm

# Test all profiles with streaming
./streaming-test-runner.sh test all

# View logs
./streaming-test-runner.sh logs
```

### Agent-Based Testing
```bash
# Run with Python agent monitor
python3 agent-monitor.py
```

## Test Phases

1. **Provisioning**: VM creation and network setup
2. **Installation**: NixOS installation with real-time monitoring
3. **Reboot**: System restart and verification
4. **Testing**: Declarative test execution
5. **Reporting**: Results aggregation and analysis

## Stream Processing

The framework monitors output streams for:
- Critical errors (immediate abort)
- Progress indicators
- Success/failure patterns
- Performance metrics

## Requirements

- QEMU/KVM with libvirt
- Python 3.8+ with asyncssh
- NixOS ISO (included in repo)
- Sufficient disk space for VMs

## Architecture

```
┌─────────────────┐
│   Test Agent    │
│  (Orchestrator) │
└────────┬────────┘
         │
    ┌────▼────┐
    │   VM    │
    │ Manager │
    └────┬────┘
         │
┌────────▼────────┐     ┌─────────────┐
│ Stream Processor├─────► Pattern     │
│ (Real-time)     │     │ Matcher     │
└────────┬────────┘     └─────────────┘
         │
    ┌────▼────┐
    │ Event   │
    │ Handler │
    └─────────┘
```

## Logs

All logs are stored in `/tmp/nixos-test-logs/`:
- `main.log` - Main execution log
- `stream.log` - Raw stream output
- `agent-thoughts.log` - Agent decision log
- `<profile>_install.log` - Installation logs
- `<profile>_test.log` - Test execution logs

## State Management

Test state is persisted in `/tmp/nixos-test-state.json` containing:
- Current test phase
- VM information
- Error tracking
- Test results

## Extending Tests

To add new test cases:

1. Add patterns to `PatternMatcher` in `agent-monitor.py`
2. Add profile-specific tests in `test_profile()` functions
3. Update declarative tests in `tests.nix`

## CI/CD Integration

The framework is designed to integrate with CI/CD systems:
- Exit codes indicate success/failure
- Structured JSON output available
- Parallel execution support
- Artifact collection

## Troubleshooting

- **VM won't start**: Check libvirt permissions and KVM availability
- **SSH timeout**: Verify network configuration and firewall rules
- **Test failures**: Check logs in `/tmp/nixos-test-logs/`
- **Stream processing issues**: Ensure Python dependencies are installed