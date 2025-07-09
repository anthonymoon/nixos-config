# Full VM disk image configuration with desktop environment
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # Workstation profile includes desktop environment
    ../profiles/workstation.nix
    ../modules/common.nix
  ];

  # Disk configuration for VM image
  fileSystems."/" = {
    device = "/dev/vda2";  # Partition 2 for hybrid partition table
    fsType = "ext4";
    autoResize = true;
  };

  fileSystems."/boot" = {
    device = "/dev/vda1";  # ESP partition
    fsType = "vfat";
  };

  boot.growPartition = true;
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub = {
    device = "/dev/vda";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.timeout = 3;

  # VM guest additions for better desktop experience
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  virtualisation.vmware.guest.enable = true;
  
  # Additional VM optimizations
  services.xserver.videoDrivers = [ "qxl" "modesetting" ];
  
  # Enable all development tools
  modules.development.enable = true;
  
  # Enable gaming support for a complete desktop experience
  modules.gaming.enable = true;
  
  # Hostname
  networking.hostName = "nixos-full";
  
  system.stateVersion = "25.05";
}