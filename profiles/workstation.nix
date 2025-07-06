# Workstation Profile - Desktop with hardware support
{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/gaming.nix
    ../modules/development.nix
  ];
  # Hardware support - generic UEFI system
  boot = {
    # Zen kernel for gaming and desktop performance optimization
    kernelPackages = pkgs.linuxKernel.packages.linux_zen;
    
    initrd = {
      availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  # Filesystem configuration handled by Disko
  # No swap devices - using ZRAM from base profile

  # Hardware settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Desktop environment
  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
      autoLogin = {
        enable = true;
        user = config.myUser.username;
      };
      defaultSession = "plasma";
    };

    desktopManager.plasma6.enable = true;
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Desktop applications
  environment.systemPackages = with pkgs; [
    # Desktop applications
    firefox
    thunderbird
    libreoffice
    vlc
    
    # Utilities
    discord
    spotify
    obsidian
    
    # System tools
    gparted
    system-config-printer
  ];

  # Enable printing
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enable flatpak
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  };

  

  # Workstation-specific directory setup
  systemd.tmpfiles.rules = [
    "d /home/${config.myUser.username}/Development 0755 ${config.myUser.username} users -"
    "d /home/${config.myUser.username}/Projects 0755 ${config.myUser.username} users -"
    "d /home/${config.myUser.username}/Downloads 0755 ${config.myUser.username} users -"
  ];
}