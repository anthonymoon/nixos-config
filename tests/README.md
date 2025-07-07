# NixOS Configuration Testing Framework

This directory contains a comprehensive automated testing framework for the NixOS configuration profiles and modules.

## Quick Start

```bash
# Run all tests
./run-tests.sh

# Run specific test
./run-tests.sh vm-profile

# Interactive mode
./run-tests.sh -i

# List available tests
./run-tests.sh -l
```

## Test Categories

### Profile Tests
Tests for each complete system profile:
- **vm-profile**: Virtual machine configuration with QEMU guest tools
- **workstation-profile**: Full desktop environment with KDE Plasma
- **server-profile**: Hardened server configuration with security features

### Module Tests
Integration tests for optional modules:
- **gaming-module**: Steam, Wine, GameMode configuration
- **development-module**: Programming languages and development tools
- **media-server-module**: Jellyfin, Radarr, Sonarr stack
- **security-module**: Fail2ban, AIDE, kernel hardening

### Deployment Tests
Installation and deployment validation:
- **deploy-vm/workstation/server**: Profile-specific deployment tests
- **disk-layout**: Partition alignment and XFS filesystem validation
- **install-recovery**: Recovery from failed installations
- **post-install-validation**: Post-installation checks

## Running Tests with Nix

```bash
# Run all tests via flake
nix flake check

# Run specific test
nix build .#checks.x86_64-linux.vm-profile

# Run test interactively for debugging
nix run .#checks.x86_64-linux.vm-profile.driverInteractive
```

## Test Structure

Each test follows the NixOS testing framework pattern:

```nix
{
  name = "test-name";
  
  nodes = {
    machine = { config, pkgs, ... }: {
      # NixOS configuration to test
    };
  };
  
  testScript = ''
    # Python test script
    machine.wait_for_unit("multi-user.target")
    machine.succeed("command-to-test")
  '';
}
```

## Writing New Tests

1. Add test definition to `integration-tests.nix` or `deployment-tests.nix`
2. Follow the existing pattern for consistency
3. Use descriptive test names
4. Include both positive and negative test cases
5. Document what the test validates

### Example Test

```nix
my-feature = makeTest {
  name = "my-feature-test";
  
  nodes.machine = { config, pkgs, ... }: {
    imports = [ self.nixosModules.my-feature ];
    # Test-specific config
  };
  
  testScript = ''
    machine.wait_for_unit("my-service.service")
    machine.succeed("validate-my-feature")
    machine.fail("invalid-command")  # Test failure cases
  '';
};
```

## Test Guidelines

### Best Practices
- Keep tests focused on specific functionality
- Use `wait_for_unit` before testing services
- Test both success and failure scenarios
- Verify configuration actually applies
- Check for security implications

### Common Test Commands
- `machine.wait_for_unit("service")` - Wait for systemd service
- `machine.wait_for_open_port(8080)` - Wait for network port
- `machine.succeed("cmd")` - Command must succeed
- `machine.fail("cmd")` - Command must fail
- `machine.wait_until_succeeds("cmd")` - Retry until success

## CI/CD Integration

Tests can be integrated into CI pipelines:

```yaml
# GitHub Actions example
- name: Run NixOS tests
  run: nix flake check
```

## Debugging Failed Tests

1. Run test interactively:
   ```bash
   ./run-tests.sh -i
   ```

2. Check logs:
   ```bash
   cat build/logs/test-name.log
   ```

3. Use interactive driver:
   ```bash
   nix run .#checks.x86_64-linux.test-name.driverInteractive
   ```

4. In interactive mode:
   ```python
   >>> start_all()
   >>> machine.shell_interact()
   ```

## Test Coverage

Current test coverage includes:
- ✅ All system profiles (vm, workstation, server)
- ✅ All optional modules
- ✅ Installation process
- ✅ Disk partitioning
- ✅ Security configurations
- ✅ Service integrations
- ✅ User management
- ✅ Network configurations

## Performance Notes

- Tests run in QEMU virtual machines
- Memory allocation per test: 1-4GB
- Disk space per test: 5-20GB
- Parallel execution supported
- Tests are cached by Nix

## Troubleshooting

### Common Issues

1. **Out of memory**: Increase system RAM or reduce test parallelism
2. **Disk space**: Tests need ~50GB free space for all tests
3. **KVM not available**: Tests work without KVM but run slower
4. **Permission denied**: Some tests need sudo for disk operations

### Getting Help

- Check test output in `build/logs/`
- Use `--show-trace` for Nix errors
- Run tests individually to isolate issues
- Check systemd journal in test VMs