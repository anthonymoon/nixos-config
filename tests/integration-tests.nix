{ self }:
let
  nixpkgs = self.inputs.nixpkgs;
  
  # Helper function to create test configurations
  makeTest = { name, nodes, testScript }:
    nixpkgs.legacyPackages.x86_64-linux.nixosTest {
      inherit name nodes testScript;
    };

  # Common test configuration
  commonConfig = {
    # Use the flake's nixpkgs
    nixpkgs.pkgs = nixpkgs.legacyPackages.x86_64-linux;
  };
in
{
  # VM Profile Tests
  vm-profile = makeTest {
    name = "vm-profile-test";
    
    nodes.machine = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.vm
      ];
      
      # Test-specific configuration
      virtualisation = {
        memorySize = 2048;
        diskSize = 10240;
      };
      
      # Override for testing
      boot.loader.grub.device = "/dev/vda";
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "xfs";
      };
      
      users.users.amoon = {
        isNormalUser = true;
        password = "test";
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test VM-specific services
      machine.succeed("systemctl is-active qemu-guest-agent.service")
      machine.succeed("systemctl is-active spice-vdagentd.service")
      
      # Test filesystem
      machine.succeed("findmnt -t xfs /")
      
      # Test user exists
      machine.succeed("id amoon")
      
      # Test VM-specific packages
      machine.succeed("which htop")
      machine.succeed("which vim")
      
      # Test boot configuration
      machine.succeed("test -d /boot/grub")
      
      # Test memory optimizations
      machine.succeed("test -f /proc/sys/vm/swappiness")
      swappiness = machine.succeed("cat /proc/sys/vm/swappiness").strip()
      assert swappiness == "10", f"Expected swappiness 10, got {swappiness}"
    '';
  };

  # Workstation Profile Tests
  workstation-profile = makeTest {
    name = "workstation-profile-test";
    
    nodes.machine = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.workstation
      ];
      
      virtualisation = {
        memorySize = 4096;
        diskSize = 20480;
      };
      
      # Override for testing
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = false;
      };
      
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "xfs";
      };
      
      fileSystems."/boot" = {
        device = "/dev/vda2";
        fsType = "vfat";
      };
      
      users.users.amoon = {
        isNormalUser = true;
        password = "test";
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test desktop environment
      machine.wait_for_unit("display-manager.service")
      
      # Test development tools
      machine.succeed("which git")
      machine.succeed("which docker")
      machine.succeed("which code")
      
      # Test audio
      machine.succeed("systemctl is-active pipewire.service")
      
      # Test gaming features
      machine.succeed("test -f /etc/security/limits.d/99-realtime.conf")
      
      # Test Docker
      machine.succeed("systemctl is-active docker.service")
      machine.succeed("docker info")
      
      # Test kernel parameters
      machine.succeed("grep -q 'mitigations=off' /proc/cmdline")
    '';
  };

  # Server Profile Tests
  server-profile = makeTest {
    name = "server-profile-test";
    
    nodes.machine = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.server
      ];
      
      virtualisation = {
        memorySize = 2048;
        diskSize = 10240;
      };
      
      # Override for testing
      boot.loader.grub.device = "/dev/vda";
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "xfs";
      };
      
      users.users.amoon = {
        isNormalUser = true;
        password = "test";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKJqgqYF9C8kokJJM7c2CjH7RSXJJR6Kc9PXxKM6qbpK test-key"
        ];
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test SSH hardening
      machine.wait_for_unit("sshd.service")
      machine.succeed("grep -q 'PermitRootLogin no' /etc/ssh/sshd_config")
      machine.succeed("grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config")
      
      # Test security modules
      machine.succeed("systemctl is-active fail2ban.service")
      
      # Test server packages
      machine.succeed("which tmux")
      machine.succeed("which htop")
      machine.succeed("which iotop")
      
      # Test firewall
      machine.succeed("systemctl is-active nftables.service")
      
      # Test automatic updates
      machine.succeed("systemctl is-active nix-gc.timer")
      machine.succeed("systemctl is-active nixos-upgrade.timer")
      
      # Test kernel hardening
      machine.succeed("sysctl kernel.kptr_restrict | grep -q '2'")
    '';
  };

  # Module Integration Tests
  gaming-module = makeTest {
    name = "gaming-module-test";
    
    nodes.machine = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.base
        self.nixosModules.gaming
      ];
      
      virtualisation = {
        memorySize = 4096;
        diskSize = 10240;
      };
      
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "xfs";
      };
      
      users.users.amoon = {
        isNormalUser = true;
        password = "test";
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test Steam installation
      machine.succeed("test -f /etc/steam/sessions.d/steam.conf || test -d /run/current-system/sw/bin/steam")
      
      # Test GameMode
      machine.succeed("which gamemoded")
      
      # Test Wine
      machine.succeed("which wine")
      machine.succeed("which wine64")
      
      # Test gaming kernel parameters
      machine.succeed("test -f /etc/sysctl.d/99-gaming.conf")
    '';
  };

  development-module = makeTest {
    name = "development-module-test";
    
    nodes.machine = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.base
        self.nixosModules.development
      ];
      
      virtualisation = {
        memorySize = 2048;
        diskSize = 10240;
      };
      
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "xfs";
      };
      
      users.users.amoon = {
        isNormalUser = true;
        password = "test";
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test programming languages
      machine.succeed("python3 --version")
      machine.succeed("node --version")
      machine.succeed("rustc --version")
      machine.succeed("go version")
      
      # Test development tools
      machine.succeed("which git")
      machine.succeed("which make")
      machine.succeed("which gcc")
      machine.succeed("which docker")
      
      # Test Docker service
      machine.succeed("systemctl is-active docker.service")
      
      # Test databases
      machine.succeed("redis-cli --version")
      machine.succeed("psql --version")
    '';
  };

  media-server-module = makeTest {
    name = "media-server-module-test";
    
    nodes.machine = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.base
        self.nixosModules.media-server
      ];
      
      virtualisation = {
        memorySize = 2048;
        diskSize = 10240;
      };
      
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "xfs";
      };
      
      users.users.amoon = {
        isNormalUser = true;
        password = "test";
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test media services
      machine.wait_for_unit("jellyfin.service")
      machine.wait_for_unit("radarr.service") 
      machine.wait_for_unit("sonarr.service")
      machine.wait_for_unit("prowlarr.service")
      machine.wait_for_unit("transmission.service")
      
      # Test service accessibility
      machine.wait_for_open_port(8096)  # Jellyfin
      machine.wait_for_open_port(7878)  # Radarr
      machine.wait_for_open_port(8989)  # Sonarr
      machine.wait_for_open_port(9696)  # Prowlarr
      machine.wait_for_open_port(9091)  # Transmission
      
      # Test user and group creation
      machine.succeed("id media")
      machine.succeed("getent group media")
    '';
  };

  security-module = makeTest {
    name = "security-module-test";
    
    nodes.machine = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.base
        self.nixosModules.security
      ];
      
      virtualisation = {
        memorySize = 1024;
        diskSize = 5120;
      };
      
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "xfs";
      };
      
      users.users.amoon = {
        isNormalUser = true;
        password = "test";
      };
    };
    
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      
      # Test fail2ban
      machine.succeed("systemctl is-active fail2ban.service")
      machine.succeed("fail2ban-client status")
      
      # Test AIDE
      machine.succeed("which aide")
      machine.succeed("test -f /etc/aide.conf")
      
      # Test kernel hardening
      machine.succeed("sysctl kernel.yama.ptrace_scope | grep -q '2'")
      machine.succeed("sysctl kernel.kptr_restrict | grep -q '2'")
      machine.succeed("sysctl kernel.unprivileged_bpf_disabled | grep -q '1'")
      
      # Test sudo configuration
      machine.succeed("grep -q 'use_pty' /etc/sudoers")
    '';
  };

  # Installation Tests
  installation-test = makeTest {
    name = "installation-test";
    
    nodes.installer = { config, pkgs, ... }: {
      imports = [
        commonConfig
        self.nixosModules.base
      ];
      
      virtualisation = {
        memorySize = 2048;
        diskSize = 20480;
        # Add a second disk for installation target
        qemu.drives = [{
          name = "target";
          file = "target.img";
          size = 10240;
        }];
      };
      
      environment.systemPackages = with pkgs; [
        git
        parted
        xfsprogs
      ];
      
      users.users.root.password = "root";
    };
    
    testScript = ''
      installer.wait_for_unit("multi-user.target")
      
      # Test disk preparation
      installer.succeed("parted /dev/vdb -- mklabel gpt")
      installer.succeed("parted /dev/vdb -- mkpart ESP fat32 1MB 1GB")
      installer.succeed("parted /dev/vdb -- set 1 esp on")
      installer.succeed("parted /dev/vdb -- mkpart primary xfs 1GB 100%")
      
      # Format partitions
      installer.succeed("mkfs.vfat -F32 /dev/vdb1")
      installer.succeed("mkfs.xfs -f /dev/vdb2")
      
      # Mount partitions
      installer.succeed("mount /dev/vdb2 /mnt")
      installer.succeed("mkdir -p /mnt/boot")
      installer.succeed("mount /dev/vdb1 /mnt/boot")
      
      # Test that we can generate a configuration
      installer.succeed("nixos-generate-config --root /mnt")
      installer.succeed("test -f /mnt/etc/nixos/configuration.nix")
      installer.succeed("test -f /mnt/etc/nixos/hardware-configuration.nix")
    '';
  };
}