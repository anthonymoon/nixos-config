# VM Profile - Optimizations for virtual machines
{ config, lib, pkgs, ... }:

{
  # VM-optimized packages
  environment.systemPackages = with pkgs; [
    # Base packages plus VM tools
    spice-gtk  # For SPICE clipboard/file sharing
  ];

  # VM-specific services
  services = {
    # Guest agent services (already enabled in vm-qemu.nix hardware profile)
    
    # Faster boot for VMs
    systemd-timesyncd.enable = false; # Not needed in VMs usually
  };

  # VM performance optimizations
  boot.kernelParams = [
    # VM-friendly parameters
    "elevator=noop"
    "transparent_hugepage=never"
  ];

  # Disable hardware-specific services that don't work in VMs
  powerManagement.enable = false;
  services.thermald.enable = false;
  hardware.pulseaudio.enable = false;
  
  # Fast network for VMs
  systemd.services.NetworkManager-wait-online.enable = false;
  
  # VM-optimized sysctl
  boot.kernel.sysctl = {
    "vm.swappiness" = 1;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };
}