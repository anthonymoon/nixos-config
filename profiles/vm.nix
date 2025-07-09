# VM Profile - Virtual machine optimized
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Filesystem configuration handled by Disko
  # No swap devices - using ZRAM from base profile
  # Hardware configuration handled by universal kernel module

  # VM hardware settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  
  # VM-specific optimizations (override kernel module defaults)
  powerManagement.cpuFreqGovernor = lib.mkForce "ondemand";
  hardware.cpu.intel.updateMicrocode = false; # Not needed in VMs
  hardware.cpu.amd.updateMicrocode = false; # Not needed in VMs
  
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