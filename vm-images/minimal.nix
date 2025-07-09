# Minimal VM disk image configuration
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # Base system configuration
    ../profiles/base.nix
    ../modules/common.nix
    ../modules/kernel.nix
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
  boot.loader.timeout = 0;

  # Enable serial console
  services.getty.autologinUser = "root";
  
  # Minimal package set - no GUI
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    tmux
  ];

  # VM guest additions
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # Disable documentation to save space
  documentation.enable = false;
  documentation.nixos.enable = false;
  
  # Optimize for VM usage
  services.xserver.enable = false;
  
  # Hostname
  networking.hostName = "nixos-minimal";
  
  system.stateVersion = "25.05";
}