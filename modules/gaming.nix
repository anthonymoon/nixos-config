# Gaming Configuration Module
# High-performance gaming support for workstations

{ config, pkgs, lib, ... }:

{
  options.modules.gaming.enable = lib.mkEnableOption "gaming configuration";

  config = lib.mkIf config.modules.gaming.enable {
    # Gaming programs
    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        gamescopeSession.enable = true;
        
        package = pkgs.steam.override {
          extraPkgs = pkgs: with pkgs; [
            xorg.libXcursor
            xorg.libXi
            xorg.libXinerama
            xorg.libXScrnSaver
            libpng
            libpulseaudio
            libvorbis
            stdenv.cc.cc.lib
            libkrb5
            keyutils
          ];
        };
      };
      
      gamemode = {
        enable = true;
        settings = {
          general = {
            renice = 10;
            inhibit_screensaver = 1;
          };
          
          gpu = {
            apply_gpu_optimisations = "accept-responsibility";
            gpu_device = 0;
            amd_performance_level = "high";
          };
          
          cpu = {
            park_cores = "no";
            pin_cores = "yes";
          };
          
          custom = {
            start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
            end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
          };
        };
      };
    };
    
    # Gaming packages
    environment.systemPackages = with pkgs; [
      # Game launchers
      lutris
      bottles
      heroic
      
      # Wine and compatibility
      wineWowPackages.stable
      winetricks
      protontricks
      
      # Performance monitoring
      mangohud
      goverlay
      
      # Controller support
      sc-controller
      
      # Vulkan tools
      vulkan-tools
      
      # Other gaming utilities
      gamemode
      gamescope
    ];
    
    # Enable 32-bit support
    hardware.graphics.enable32Bit = true;
    
    # Controller support
    hardware.xone.enable = true;
    
    # Steam controller udev rules
    services.udev.packages = [ pkgs.steam ];
    
    # Low latency audio configuration
    services.pipewire.lowLatency = {
      enable = true;
      quantum = 64;
      rate = 48000;
    };
  };
}