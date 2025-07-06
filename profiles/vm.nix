# VM Profile - Virtual machine optimized
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # VM-specific boot modules
  boot = {
    # LTS kernel for VM stability and mature virtio support
    kernelPackages = pkgs.linuxKernel.packages.linux_6_6;
    
    initrd = {
      availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
      kernelModules = [ ];
    };
    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  # Filesystem configuration - fallback for testing
  # In production, this is overridden by hardware-configuration.nix
  fileSystems = lib.mkDefault {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "xfs";
      options = [ "defaults" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [ "defaults" ];
    };
  };
  
  # No swap by default
  swapDevices = [ ];

  # VM hardware settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = false; # Not needed in VMs
  
  # VM optimizations
  services = {
    spice-vdagentd.enable = true;
    qemuGuest.enable = true;
  };

  # VM-specific packages
  environment.systemPackages = with pkgs; [
    spice-vdagent
    qemu-utils
  ];
}