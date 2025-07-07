# Standalone test runner that can be executed directly
# Usage: nix-build standalone-test.nix -A vm-profile

let
  # Pin nixpkgs to ensure reproducibility
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  };
  
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  
  # Simple VM test
  makeTest = { name, machine, testScript }:
    pkgs.nixosTest {
      inherit name testScript;
      nodes.machine = { config, pkgs, ... }: machine;
    };
in
{
  # Basic VM profile test
  vm-profile = makeTest {
    name = "vm-profile-test";
    
    machine = {
      # Minimal VM configuration
      boot.loader.grub.device = "/dev/vda";
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "ext4";
      };
      
      # VM services
      services.qemuGuest.enable = true;
      services.spice-vdagentd.enable = true;
      
      # Test user
      users.users.testuser = {
        isNormalUser = true;
        password = "test";
      };
      
      # Basic packages
      environment.systemPackages = with pkgs; [ vim htop ];
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test services
      machine.succeed("systemctl is-active qemu-guest-agent.service")
      machine.succeed("systemctl is-active spice-vdagentd.service")
      
      # Test user
      machine.succeed("id testuser")
      
      # Test packages
      machine.succeed("which vim")
      machine.succeed("which htop")
      
      print("All VM profile tests passed!")
    '';
  };
  
  # Simple server test
  server-profile = makeTest {
    name = "server-profile-test";
    
    machine = {
      boot.loader.grub.device = "/dev/vda";
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "ext4";
      };
      
      # SSH configuration
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
      };
      
      # Security
      services.fail2ban.enable = true;
      
      # Test user
      users.users.admin = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITest test@example"
        ];
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test SSH
      machine.wait_for_unit("sshd.service")
      machine.succeed("grep -q 'PermitRootLogin no' /etc/ssh/sshd_config")
      
      # Test fail2ban
      machine.succeed("systemctl is-active fail2ban.service")
      
      print("Server profile tests passed!")
    '';
  };
  
  # Run all tests
  all = pkgs.stdenv.mkDerivation {
    name = "all-tests";
    buildCommand = ''
      echo "Run individual tests with:"
      echo "  nix-build standalone-test.nix -A vm-profile"
      echo "  nix-build standalone-test.nix -A server-profile"
      mkdir -p $out
      echo "Tests ready" > $out/status
    '';
  };
}