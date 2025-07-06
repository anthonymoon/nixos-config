# 🤖 NixOS Agent-Based Testing Framework

A revolutionary real-time monitoring and self-healing testing system for NixOS installations.

## 🎯 Overview

This testing framework goes beyond traditional CI/CD by providing:

- **Real-time installation monitoring** with structured output parsing
- **Intelligent pattern recognition** for automated problem detection
- **Self-healing capabilities** for common installation failures
- **Pristine VM environments** for every test run
- **Comprehensive reporting** with detailed analysis

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Test           │    │  Agent Monitor   │    │  Self-Healing   │
│  Orchestrator   ├───▶│  (Real-time)     ├───▶│  Engine         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  VM Manager     │    │  Stream Runner   │    │  Config Fixer   │
│  (Snapshots)    │    │  (SSH Monitor)   │    │  (Auto-repair)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

```bash
# Install required tools
sudo apt install libvirt-daemon-system virt-manager qemu-utils
sudo usermod -a -G libvirt $USER
sudo systemctl enable --now libvirtd

# Or on NixOS:
nix-shell -p libvirt qemu virt-manager
```

### Basic Usage

```bash
# Setup test environment (one-time)
./testing/test-orchestrator.sh setup

# Test all profiles with agent monitoring
./testing/test-orchestrator.sh test

# Test specific profile
./testing/test-orchestrator.sh test vm

# Test with self-healing enabled
./testing/test-orchestrator.sh --profiles vm,server test
```

## 🔧 Components

### 1. VM Manager (`vm-manager.sh`)
- Creates and manages pristine VM environments
- Handles snapshots for clean test states
- Manages VM lifecycle (start, stop, revert)

```bash
# Manual VM operations
./testing/vm-manager.sh setup     # Create base VM
./testing/vm-manager.sh clean     # Revert to clean state
./testing/vm-manager.sh ip        # Get VM IP address
```

### 2. Agent Monitor (`agent-monitor.py`)
- Real-time monitoring of installation streams
- Intelligent pattern recognition
- Automated response to failures
- Integration with self-healing engine

### 3. Self-Healing Engine (`self_healing.py`)
- Automated error analysis and recovery
- Configuration fixes on-the-fly
- Multiple healing strategies per error type
- Confidence-based action selection

### 4. Stream Runner (`stream-runner.sh`)
- Structured output generation
- Real-time installation monitoring
- Post-installation verification
- Integration with agent monitoring

### 5. Test Orchestrator (`test-orchestrator.sh`)
- Complete test automation
- Multi-profile testing
- Comprehensive reporting
- CLI interface

## 📊 Structured Output Format

The framework uses structured output for intelligent monitoring:

```
::PHASE::<phase_name>           # Installation phase changes
::SUCCESS::<message>            # Successful operations
::ERROR::<error_description>    # Errors requiring attention
::WARNING::<warning_message>    # Non-critical warnings
::CONTEXT::<contextual_info>    # Additional context
::PROGRESS::<stage>::<details>  # Progress indicators
::METRIC::<name>::<value>       # System metrics
```

## 🩺 Self-Healing Capabilities

### Supported Error Types

1. **Disk Detection Failures**
   - Auto-detects available disks
   - Generates corrected disko configurations
   - Fallback to manual disk specification

2. **Network Connectivity Issues**
   - DNS resolution fixes
   - Alternative cache servers
   - Network interface recovery

3. **Memory Pressure**
   - Emergency swap creation
   - Cache cleanup
   - Memory optimization

4. **Disk Space Issues**
   - Temporary file cleanup
   - Nix store optimization
   - Log rotation

### Example Healing Process

```
🔧 AUTOMATED RESPONSE: Disk detection failure
   → Checking available disks...
   → Found: /dev/vda (20GB)
   → Generating fixed disko-config.nix
   → Confidence: 90%
✅ Self-healing successful! Continuing installation...
```

## 📈 Monitoring and Reporting

### Real-time Monitoring

```
📍 PHASE: DISK_PARTITIONING
⏳ PROGRESS: Creating GPT partition table
✅ SUCCESS: Disk partitioning complete
📍 PHASE: FILESYSTEM_MOUNTING
ℹ️  CONTEXT: Using Btrfs with compression
```

### Comprehensive Reports

Generated reports include:
- Installation duration by phase
- Error counts and types
- Healing attempts and success rates
- System metrics during installation
- Detailed logs for debugging

## 🧪 Testing Workflow

### 1. Environment Setup
```bash
# Creates base VM with NixOS installer
# Takes snapshot for pristine state
./testing/test-orchestrator.sh setup
```

### 2. Profile Testing
```bash
# For each profile (vm, workstation, server):
# 1. Revert VM to clean snapshot
# 2. Deploy current nixos-config
# 3. Run monitored installation
# 4. Verify post-installation state
./testing/test-orchestrator.sh test
```

### 3. Real-time Monitoring
- Agent parses structured output
- Patterns trigger automated responses
- Self-healing attempts error recovery
- Progress displayed in real-time

### 4. Post-installation Verification
- System reboot monitoring
- Service status verification
- Profile-specific checks
- Final success confirmation

## 📁 Directory Structure

```
testing/
├── README.md                    # This documentation
├── test-orchestrator.sh         # Main test controller
├── vm-manager.sh               # VM lifecycle management
├── agent-monitor.py            # Real-time monitoring
├── self_healing.py             # Automated error recovery
├── stream-runner.sh            # Installation monitoring
├── stream-runner-internal.sh   # Internal monitoring helper
└── logs/                       # Generated logs and reports
    ├── test_vm_20241206_143022.log
    ├── agent_monitor_vm_1701865822.json
    └── final_report_vm_1701865822.json
```

## 🎛️ Configuration

### Environment Variables

```bash
# VM Configuration
export VM_MEMORY="4096"         # VM memory in MB
export VM_DISK_SIZE="20G"       # VM disk size
export VM_NETWORK="default"     # Libvirt network

# Testing Configuration
export PARALLEL_TESTS="false"   # Enable parallel testing
export MAX_HEALING_ATTEMPTS="3" # Self-healing attempt limit
```

### Healing Configuration

Modify `self_healing.py` to add custom healing patterns:

```python
# Add custom healing action
actions.append(HealingAction(
    name="custom_fix",
    description="Custom error recovery",
    confidence=0.8,
    commands=["custom-fix-command"],
    config_changes={"file.nix": "new content"}
))
```

## 🔍 Debugging

### Log Locations

- **Test logs**: `/tmp/nixos-testing/logs/test_<profile>_<timestamp>.log`
- **Agent logs**: `/tmp/nixos-testing/logs/agent_monitor_<profile>_<timestamp>.json`
- **Healing logs**: `/tmp/nixos-testing/logs/self_healing.json`
- **Reports**: `/tmp/nixos-testing/reports/`

### Troubleshooting

```bash
# Check VM status
./testing/vm-manager.sh ip
virsh list --all

# Access VM directly
./testing/vm-manager.sh ssh

# Review recent logs
tail -f /tmp/nixos-testing/logs/test_*.log

# Check libvirt permissions
groups | grep libvirt
sudo systemctl status libvirtd
```

## 🚀 Advanced Usage

### Custom Test Profiles

```bash
# Test only specific profiles
./testing/test-orchestrator.sh --profiles vm,server test

# Skip self-healing
export HEALING_ENABLED="false"
./testing/test-orchestrator.sh test
```

### Integration with CI/CD

```yaml
# GitHub Actions example
- name: Run NixOS Installation Tests
  run: |
    sudo ./testing/test-orchestrator.sh setup
    ./testing/test-orchestrator.sh test
```

### Extending Self-Healing

Add new healing patterns by extending the `SelfHealer` class:

```python
def analyze_custom_error(self) -> List[HealingAction]:
    # Custom error analysis logic
    return [HealingAction(...)]
```

## 📊 Metrics and Analytics

The framework collects detailed metrics:

- **Installation time** by phase and total
- **Error patterns** and frequency
- **Healing success rates** by error type
- **System resource usage** during installation
- **Network performance** metrics

## 🎯 Future Enhancements

- [ ] Parallel testing across multiple VMs
- [ ] Integration with existing nixos-tests
- [ ] Web dashboard for real-time monitoring
- [ ] ML-based error pattern recognition
- [ ] Distributed testing across cloud providers

## 🤝 Contributing

To extend the testing framework:

1. Add new patterns to `agent-monitor.py`
2. Implement healing actions in `self_healing.py`
3. Extend verification in `stream-runner.sh`
4. Update documentation

## 📝 License

This testing framework is part of the NixOS configuration repository and follows the same license terms.