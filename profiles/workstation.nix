# Workstation Profile - Desktop with hardware support
{ config, lib, pkgs, username, ... }:

{
  imports = [
    ../modules/gaming.nix
    ../modules/development.nix
    
  ];
  
  # Enable gaming and development features by default for workstations
  modules.gaming.enable = true;
  modules.development.enable = true;
  
  # Filesystem configuration handled by Disko
  # No swap devices - using ZRAM from base profile
  # Hardware configuration handled by universal kernel module

  # Platform settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

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

  

  # Workstation-specific directory setup
  systemd.tmpfiles.rules = lib.mkIf (username != null) [
    "d /home/${username}/Development 0755 ${username} users -"
    "d /home/${username}/Projects 0755 ${username} users -"
    "d /home/${username}/Downloads 0755 ${username} users -"
  ];
}