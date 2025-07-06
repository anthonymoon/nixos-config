# NixOS Integration Tests
# Modern, declarative testing using the native nixos-tests framework
# Replaces the over-engineered bash testing scripts

{ pkgs, lib, ... }:

{
  # Test all three main configurations
  vm-test = pkgs.nixosTest {
    name = "vm-configuration-test";
    
    nodes.vm = {
      imports = [
        ./profiles/base.nix
        ./profiles/vm.nix
        ./disko-config.nix
      ];
      
      # Test-specific configuration
      virtualisation = {
        memorySize = 2048;
        diskSize = 8192;
      };
      
      myUser.username = "testuser";
      users.users.testuser.password = "test";
    };
    
    testScript = ''
      vm.start()
      vm.wait_for_unit("default.target")
      
      # Test basic system functionality
      vm.succeed("systemctl is-active sshd")
      vm.succeed("systemctl is-active NetworkManager")
      
      # Test user setup
      vm.succeed("id testuser")
      vm.succeed("sudo -u testuser whoami")
      
      # Test filesystem
      output = vm.succeed("stat -f / --format='%T'")
      assert "btrfs" in output, f"Expected btrfs filesystem, got: {output}"
      
      # Test ZRAM swap
      vm.succeed("swapon --show | grep zram")
      
      # Test VM-specific services
      vm.succeed("systemctl is-active qemu-guest-agent")
      
      # Test package availability
      vm.succeed("command -v htop")
      vm.succeed("command -v git")
      vm.succeed("command -v zsh")

      # Additional validation checks from automated-profile-test.sh
      vm.succeed("nixos-version")
      
      profile_output = vm.succeed("grep -E \"(profile|workstation|server|vm)\" /etc/nixos/configuration.nix | head -5")
      assert "vm" in profile_output, f"Expected 'vm' profile in configuration, got: {profile_output}"
      
      failed_services = vm.succeed("systemctl list-units --failed --no-legend")
      assert "0 loaded units" in failed_services or not failed_services.strip(), f"Failed services found: {failed_services}"
      
      vm.succeed("df -h /")
      vm.succeed("ip -4 addr show")
      vm.succeed("free -h")
      vm.succeed("nproc")
    '';
  };
  
  workstation-test = pkgs.nixosTest {
    name = "workstation-configuration-test";
    
    nodes.workstation = {
      imports = [
        ./profiles/base.nix
        ./profiles/workstation.nix
        ./disko-config.nix
      ];
      
      virtualisation = {
        memorySize = 4096;
        diskSize = 16384;
        graphics = true;
      };
      
      myUser.username = "testuser";
      users.users.testuser.password = "test";
      
      # Enable test modules
      modules = {
        gaming.enable = true;
        development.enable = true;
      };
    };
    
    testScript = ''
      workstation.start()
      workstation.wait_for_unit("default.target")
      
      # Test desktop environment
      workstation.wait_for_unit("default.target")
      workstation.wait_for_unit("display-manager.service")
      workstation.wait_for_unit("plasma-kwin_x11.service", timeout=30)
      
      # Test development tools
      workstation.succeed("command -v code")
      workstation.succeed("command -v docker")
      workstation.succeed("systemctl is-active docker")
      
      # Test gaming packages
      workstation.succeed("command -v steam")
      workstation.succeed("command -v lutris")
      
      # Test audio
      workstation.succeed("systemctl is-active pipewire")
      
      # Test package availability
      workstation.succeed("command -v firefox")
      workstation.succeed("command -v git")

      # Additional validation checks from automated-profile-test.sh
      workstation.succeed("nixos-version")
      
      profile_output = workstation.succeed("grep -E \"(profile|workstation|server|vm)\" /etc/nixos/configuration.nix | head -5")
      assert "workstation" in profile_output, f"Expected 'workstation' profile in configuration, got: {profile_output}"
      
      failed_services = workstation.succeed("systemctl list-units --failed --no-legend")
      assert "0 loaded units" in failed_services or not failed_services.strip(), f"Failed services found: {failed_services}"
      
      workstation.succeed("df -h /")
      workstation.succeed("ip -4 addr show")
      workstation.succeed("free -h")
      workstation.succeed("nproc")
    '';
  };
  
  server-test = pkgs.nixosTest {
    name = "server-configuration-test";
    
    nodes.server = {
      imports = [
        ./profiles/base.nix
        ./profiles/server.nix
        ./disko-config.nix
      ];
      
      virtualisation = {
        memorySize = 2048;
        diskSize = 8192;
        graphics = false;
      };
      
      myUser.username = "testuser";
      users.users.testuser.password = "test";
      
      # Enable security module
      modules.security.enable = true;
    };
    
    testScript = ''
      server.start()
      server.wait_for_unit("default.target")
      
      # Test headless operation (no GUI)
      server.fail("systemctl is-active display-manager.service")
      
      # Test SSH security hardening
      server.succeed("systemctl is-active sshd")
      
      # Test firewall
      server.succeed("systemctl is-active firewall")
      
      # Test fail2ban
      server.succeed("systemctl is-active fail2ban")
      
      # Test docker
      server.succeed("systemctl is-active docker")
      
      # Test security packages
      server.succeed("command -v aide")
      server.succeed("command -v fail2ban-client")
      
      # Test network tools
      server.succeed("command -v nmap")
      server.succeed("command -v netcat")
      
      # Test filesystem and swap
      output = server.succeed("stat -f / --format='%T'")
      assert "btrfs" in output, f"Expected btrfs filesystem, got: {output}"
      server.succeed("swapon --show | grep zram")

      # Additional validation checks from automated-profile-test.sh
      server.succeed("nixos-version")
      
      profile_output = server.succeed("grep -E \"(profile|workstation|server|vm)\" /etc/nixos/configuration.nix | head -5")
      assert "server" in profile_output, f"Expected 'server' profile in configuration, got: {profile_output}"
      
      failed_services = server.succeed("systemctl list-units --failed --no-legend")
      assert "0 loaded units" in failed_services or not failed_services.strip(), f"Failed services found: {failed_services}"
      
      server.succeed("df -h /")
      server.succeed("ip -4 addr show")
      server.succeed("free -h")
      server.succeed("nproc")
    '';
  };
  
  # Combined multi-node test for network scenarios
  network-test = pkgs.nixosTest {
    name = "network-configuration-test";
    
    nodes = {
      server = {
        imports = [
          ./profiles/base.nix
          ./profiles/server.nix
          ./disko-config.nix
        ];
        
        virtualisation.memorySize = 1024;
        myUser.username = "testuser";
        users.users.testuser.password = "test";
        modules.security.enable = true;
        
        networking = {
          firewall.allowedTCPPorts = [ 22 ];
          interfaces.eth1.ipv4.addresses = [{
            address = "192.168.1.10";
            prefixLength = 24;
          }];
        };
      };
      
      client = {
        imports = [
          ./profiles/base.nix
          ./profiles/vm.nix
          ./disko-config.nix
        ];
        
        virtualisation.memorySize = 1024;
        myUser.username = "testuser";
        users.users.testuser.password = "test";
        
        networking.interfaces.eth1.ipv4.addresses = [{
          address = "192.168.1.20";
          prefixLength = 24;
        }];
      };
    };
    
    testScript = ''
      server.start()
      client.start()
      
      server.wait_for_unit("default.target")
      client.wait_for_unit("default.target")
      
      # Test network connectivity
      client.succeed("ping -c 3 192.168.1.10")
      
      # Test SSH connectivity (should work from client to server)
      server.wait_for_unit("sshd")
      client.succeed("nc -z 192.168.1.10 22")
    '';
  };
}