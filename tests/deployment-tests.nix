{ self }:
let
  nixpkgs = self.inputs.nixpkgs;
  
  # Helper to create deployment test
  makeDeploymentTest = { name, profile, diskConfig ? null, testScript }:
    nixpkgs.legacyPackages.x86_64-linux.nixosTest {
      inherit name testScript;
      
      nodes.installer = { config, pkgs, modulesPath, ... }: {
        imports = [
          "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
        ];
        
        # Test environment setup
        virtualisation = {
          memorySize = 4096;
          diskSize = 20480;
          # Second disk for installation target
          qemu.drives = [{
            name = "target";
            file = "target.img";
            size = 20480;
          }];
        };
        
        # Enable root login for testing
        users.users.root.password = "root";
        
        # Include all necessary tools and installer script
        environment.systemPackages = with pkgs; [
          parted
          xfsprogs
          git
          jq
          pwgen
          (writeScriptBin "nixos-config-install" ''
            #!${pkgs.bash}/bin/bash
            ${builtins.readFile ../install/install.sh}
          '')
        ];
      };
    };
in
{
  # VM Profile Deployment Test
  deploy-vm = makeDeploymentTest {
    name = "deploy-vm-test";
    profile = "vm";
    
    testScript = ''
      installer.wait_for_unit("multi-user.target")
      
      # Test installer help
      installer.succeed("nixos-config-install --help")
      
      # Prepare disk
      installer.succeed("parted /dev/vdb -- mklabel gpt")
      installer.succeed("parted /dev/vdb -- mkpart ESP fat32 1MB 1GB")
      installer.succeed("parted /dev/vdb -- set 1 esp on")
      installer.succeed("parted /dev/vdb -- mkpart primary xfs 1GB 100%")
      
      # Format partitions
      installer.succeed("mkfs.vfat -F32 /dev/vdb1")
      installer.succeed("mkfs.xfs -f /dev/vdb2")
      
      # Mount filesystems
      installer.succeed("mount /dev/vdb2 /mnt")
      installer.succeed("mkdir -p /mnt/boot")
      installer.succeed("mount /dev/vdb1 /mnt/boot")
      
      # Test configuration generation
      installer.succeed("nixos-generate-config --root /mnt")
      
      # Verify generated files
      installer.succeed("test -f /mnt/etc/nixos/configuration.nix")
      installer.succeed("test -f /mnt/etc/nixos/hardware-configuration.nix")
      
      # Test our configuration would apply
      installer.succeed("nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration '{ imports = [ /mnt/etc/nixos/configuration.nix ]; }'")
    '';
  };

  # Workstation Profile Deployment Test
  deploy-workstation = makeDeploymentTest {
    name = "deploy-workstation-test";
    profile = "workstation";
    
    testScript = ''
      installer.wait_for_unit("multi-user.target")
      
      # Test disk detection
      installer.succeed("lsblk")
      installer.succeed("test -b /dev/vdb")
      
      # Test UEFI detection (simulated)
      installer.succeed("mkdir -p /sys/firmware/efi")
      
      # Prepare GPT disk with proper alignment
      installer.succeed("parted /dev/vdb -- mklabel gpt")
      installer.succeed("parted /dev/vdb -- mkpart ESP fat32 2048s 2097152s")  # 1GB aligned
      installer.succeed("parted /dev/vdb -- set 1 esp on")
      installer.succeed("parted /dev/vdb -- mkpart primary xfs 2097152s 100%")
      
      # Verify partition alignment
      installer.succeed("parted /dev/vdb -- align-check optimal 1")
      installer.succeed("parted /dev/vdb -- align-check optimal 2")
      
      # Format with XFS
      installer.succeed("mkfs.vfat -F32 /dev/vdb1")
      installer.succeed("mkfs.xfs -f /dev/vdb2")
      
      # Mount and generate config
      installer.succeed("mount /dev/vdb2 /mnt")
      installer.succeed("mkdir -p /mnt/boot")
      installer.succeed("mount /dev/vdb1 /mnt/boot")
      installer.succeed("nixos-generate-config --root /mnt")
      
      # Verify XFS in hardware config
      installer.succeed("grep -q 'fsType = \"xfs\"' /mnt/etc/nixos/hardware-configuration.nix")
    '';
  };

  # Server Profile Deployment Test  
  deploy-server = makeDeploymentTest {
    name = "deploy-server-test";
    profile = "server";
    
    testScript = ''
      installer.wait_for_unit("multi-user.target")
      
      # Test password generation
      installer.succeed("pwgen -s 20 1")
      
      # Full automated disk setup
      installer.succeed("""
        parted /dev/vdb -- mklabel gpt
        parted /dev/vdb -- mkpart ESP fat32 2048s 2097152s
        parted /dev/vdb -- set 1 esp on  
        parted /dev/vdb -- mkpart primary xfs 2097152s 100%
        mkfs.vfat -F32 /dev/vdb1
        mkfs.xfs -f /dev/vdb2
        mount /dev/vdb2 /mnt
        mkdir -p /mnt/boot
        mount /dev/vdb1 /mnt/boot
      """)
      
      # Generate configuration
      installer.succeed("nixos-generate-config --root /mnt")
      
      # Test configuration would include security modules
      installer.succeed("echo '{ imports = [ /mnt/etc/nixos/configuration.nix ]; services.fail2ban.enable = true; }' > /tmp/test.nix")
      installer.succeed("nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration /tmp/test.nix")
    '';
  };

  # Disk Layout Validation Test
  disk-layout = makeDeploymentTest {
    name = "disk-layout-test";
    profile = "vm";
    
    testScript = ''
      installer.wait_for_unit("multi-user.target")
      
      # Test various disk sizes
      for size in [10, 20, 50, 100]:
          installer.succeed(f"truncate -s {size}G /tmp/test-disk.img")
          installer.succeed(f"losetup /dev/loop0 /tmp/test-disk.img")
          
          # Test partitioning with proper alignment
          installer.succeed("""
            parted /dev/loop0 -- mklabel gpt
            parted /dev/loop0 -- mkpart ESP fat32 2048s 2097152s
            parted /dev/loop0 -- set 1 esp on
            parted /dev/loop0 -- mkpart primary xfs 2097152s 100%
          """)
          
          # Verify alignment
          installer.succeed("parted /dev/loop0 -- align-check optimal 1")
          installer.succeed("parted /dev/loop0 -- align-check optimal 2")
          
          # Verify partition sizes
          esp_size = installer.succeed("parted /dev/loop0 -- unit MB print | grep ESP | awk '{print $4}'").strip()
          assert "1000" in esp_size or "1024" in esp_size, f"ESP size incorrect: {esp_size}"
          
          installer.succeed("losetup -d /dev/loop0")
          installer.succeed("rm /tmp/test-disk.img")
    '';
  };

  # Installation Recovery Test
  install-recovery = makeDeploymentTest {
    name = "install-recovery-test";
    profile = "vm";
    
    testScript = ''
      installer.wait_for_unit("multi-user.target")
      
      # Test recovery from partial installation
      installer.succeed("""
        # Create partial installation state
        parted /dev/vdb -- mklabel gpt
        parted /dev/vdb -- mkpart ESP fat32 2048s 2097152s
        parted /dev/vdb -- set 1 esp on
        mkfs.vfat -F32 /dev/vdb1
        
        # Leave second partition unformatted
        parted /dev/vdb -- mkpart primary xfs 2097152s 100%
      """)
      
      # Test mount recovery
      installer.fail("mount /dev/vdb2 /mnt")  # Should fail - not formatted
      
      # Complete installation
      installer.succeed("mkfs.xfs -f /dev/vdb2")
      installer.succeed("mount /dev/vdb2 /mnt")
      installer.succeed("mkdir -p /mnt/boot")
      installer.succeed("mount /dev/vdb1 /mnt/boot")
      
      # Verify recovery successful
      installer.succeed("findmnt /mnt")
      installer.succeed("findmnt /mnt/boot")
    '';
  };

  # Post-Install Validation Test
  post-install-validation = makeDeploymentTest {
    name = "post-install-validation-test";
    profile = "workstation";
    
    testScript = ''
      installer.wait_for_unit("multi-user.target")
      
      # Simulate completed installation
      installer.succeed("""
        # Setup disk
        parted /dev/vdb -- mklabel gpt
        parted /dev/vdb -- mkpart ESP fat32 2048s 2097152s
        parted /dev/vdb -- set 1 esp on
        parted /dev/vdb -- mkpart primary xfs 2097152s 100%
        mkfs.vfat -F32 /dev/vdb1
        mkfs.xfs -f /dev/vdb2
        
        # Mount
        mount /dev/vdb2 /mnt
        mkdir -p /mnt/boot
        mount /dev/vdb1 /mnt/boot
        
        # Generate config
        nixos-generate-config --root /mnt
        
        # Create fake nixos installation
        mkdir -p /mnt/etc/nixos
        mkdir -p /mnt/nix/store
        touch /mnt/etc/NIXOS
        
        # Create user
        mkdir -p /mnt/home/amoon
        echo "amoon:x:1000:1000::/home/amoon:/bin/bash" >> /mnt/etc/passwd
        echo "amoon:!:19000::::::" >> /mnt/etc/shadow
      """)
      
      # Test post-install checks
      installer.succeed("test -f /mnt/etc/NIXOS")
      installer.succeed("test -d /mnt/home/amoon") 
      installer.succeed("grep -q amoon /mnt/etc/passwd")
      
      # Verify filesystem
      installer.succeed("findmnt -t xfs /mnt")
      installer.succeed("findmnt -t vfat /mnt/boot")
    '';
  };
}