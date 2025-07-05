# Generic UEFI Hardware Profile - For physical machines
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Generic boot modules - covers most hardware
  boot = {
    initrd = {
      availableKernelModules = [ 
        "xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" 
        "nvme" "sata_sil24" "ata_piix" "mptspi" "mptsas" "mptbase"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModulePackages = [ ];
  };

  # Predictable filesystem layout using labels
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # No swap by default (can be overridden)
  swapDevices = [ ];

  # Generic hardware settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  
  # Enable all firmware for maximum hardware compatibility
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
}