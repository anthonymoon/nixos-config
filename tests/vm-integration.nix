# VM Integration Test Suite
# This creates a NixOS test VM that validates the complete system configuration

import <nixpkgs/nixos/tests/make-test-python.nix> ({ pkgs, lib, ... }:

{
  name = "nixos-config-integration-test";
  
  meta = with lib.maintainers; {
    maintainers = [ /* your maintainer info */ ];
    description = "Integration tests for NixOS configuration";
  };

  nodes = {
    # Test VM node with our configuration
    testvm = { config, pkgs, modulesPath, ... }: {
      imports = [
        ../hosts/nixos/default.nix
        (modulesPath + "/virtualisation/qemu-vm.nix")
      ];
      
      # Override VM-specific settings for testing
      virtualisation = {
        memorySize = 4096;
        cores = 4;
        diskSize = 20480; # 20GB
        graphics = false;
        
        # Enable nested virtualization for testing Docker
        qemu.options = [ "-enable-kvm" ];
        
        # Network configuration for testing
        vlans = [ 1 ];
        interfaces.eth1 = {
          ipv4.addresses = [{
            address = "192.168.1.100";
            prefixLength = 24;
          }];
        };
      };
      
      # Disable some services that don't work well in test VMs
      services = {
        jellyfin.enable = lib.mkForce false;
        samba.enable = lib.mkForce false;
        netdata.enable = lib.mkForce false;
        nginx.enable = lib.mkForce false;
        mpd.enable = lib.mkForce false;
        avahi.enable = lib.mkForce false;
        wsdd.enable = lib.mkForce false;
        nfs.server.enable = lib.mkForce false;
      };
      
      # Enable some test-specific services
      services.openssh.enable = true;
      services.openssh.settings.PermitRootLogin = "yes";
      
      # Test user setup
      users.users.root.password = "test";
      users.users.amoon.password = "test";
      
      # Ensure test packages are available
      environment.systemPackages = with pkgs; [
        curl
        jq
        stress
        iperf3
      ];
    };
  };

  testScript = ''
    import json
    import time
    
    # Start the test VM
    testvm.start()
    
    # Wait for the system to boot
    testvm.wait_for_unit("multi-user.target")
    testvm.wait_for_unit("sshd")
    
    # Test 1: System Boot and Basic Services
    with subtest("System boot and critical services"):
        testvm.succeed("systemctl is-system-running --wait")
        testvm.succeed("systemctl is-active sshd")
        testvm.succeed("systemctl is-active systemd-networkd")
        
        # Verify system is detected as VM
        testvm.succeed("grep -i qemu /sys/class/dmi/id/sys_vendor")
        print("✅ System correctly detected as VM")

    # Test 2: User Environment
    with subtest("User environment and shell"):
        testvm.succeed("su - amoon -c 'echo $SHELL' | grep zsh")
        testvm.succeed("su - amoon -c 'which nvim'")
        testvm.succeed("su - amoon -c 'which git'")
        testvm.succeed("su - amoon -c 'id' | grep 'wheel'")
        print("✅ User environment configured correctly")

    # Test 3: Package Availability
    with subtest("Package availability"):
        packages_to_test = [
            "git", "nvim", "zsh", "docker", "curl", "htop", "fd", "rg", "bat"
        ]
        
        for package in packages_to_test:
            testvm.succeed(f"which {package}")
        print("✅ All essential packages available")

    # Test 4: Docker Service
    with subtest("Docker service and functionality"):
        testvm.succeed("systemctl is-active docker")
        testvm.succeed("docker version")
        testvm.succeed("docker run --rm hello-world")
        print("✅ Docker service working correctly")

    # Test 5: Network Configuration
    with subtest("Network configuration"):
        # Test VM-specific DHCP network config
        testvm.succeed("ip addr show eth0")
        
        # Test DNS resolution
        testvm.succeed("nslookup google.com 8.8.8.8")
        
        # Test external connectivity
        testvm.succeed("curl -I --connect-timeout 10 https://google.com")
        print("✅ Network configuration working")

    # Test 6: Filesystem and Storage
    with subtest("Filesystem and storage"):
        # Check filesystem mounts
        testvm.succeed("mount | grep 'on / '")
        testvm.succeed("mount | grep 'on /boot '")
        
        # Test disk usage
        testvm.succeed("df -h | grep -E '(/$|/boot)'")
        
        # Test ZRAM if enabled
        result = testvm.succeed("swapon --show --noheadings || echo 'no swap'")
        if "zram" in result:
            print("✅ ZRAM swap detected")
        print("✅ Filesystem configuration correct")

    # Test 7: Security Configuration  
    with subtest("Security configuration"):
        # Test sudo configuration
        testvm.succeed("su - amoon -c 'sudo -l | grep NOPASSWD'")
        
        # Test SSH configuration
        ssh_config = testvm.succeed("sshd -T")
        assert "passwordauthentication yes" in ssh_config.lower()
        assert "permitrootlogin yes" in ssh_config.lower()
        
        print("✅ Security configuration as expected")

    # Test 8: VM-Specific Optimizations
    with subtest("VM-specific optimizations"):
        # Check sysctl settings for VM
        sysctl_output = testvm.succeed("sysctl vm.swappiness")
        assert "vm.swappiness = 1" in sysctl_output
        
        # Check that VM-specific services are disabled
        testvm.fail("systemctl is-active jellyfin")
        testvm.fail("systemctl is-active samba") 
        
        # Check tuned profile
        tuned_profile = testvm.succeed("tuned-adm active")
        assert "virtual-guest" in tuned_profile
        
        print("✅ VM optimizations applied correctly")

    # Test 9: Performance Under Load
    with subtest("Performance under load"):
        # CPU stress test
        testvm.succeed("timeout 30 stress --cpu 2 --timeout 20s")
        
        # Memory stress test  
        testvm.succeed("timeout 30 stress --vm 1 --vm-bytes 512M --timeout 20s")
        
        # Verify system remains responsive
        testvm.succeed("systemctl is-system-running")
        
        print("✅ System stable under load")

    # Test 10: Configuration Validation
    with subtest("Configuration validation"):
        # Check that the configuration can be evaluated
        testvm.succeed("nix-instantiate --eval '<nixpkgs/nixos>' -A config.system.build.toplevel --json >/dev/null")
        
        # Check for any systemd failed units
        failed_units = testvm.succeed("systemctl --failed --no-legend --no-pager | wc -l").strip()
        if int(failed_units) > 0:
            failed_list = testvm.succeed("systemctl --failed --no-legend --no-pager")
            print(f"⚠️ Failed units detected: {failed_list}")
        else:
            print("✅ No failed systemd units")

    # Test 11: Hyprland Environment (if available)
    with subtest("Hyprland window manager"):
        # Test that Hyprland is available
        testvm.succeed("which hyprland")
        
        # Test Wayland-specific packages
        testvm.succeed("which wl-clipboard")
        
        # Check XWayland support
        testvm.succeed("which Xwayland")
        
        print("✅ Hyprland environment configured")

    print("🎉 All integration tests passed!")
  '';
})