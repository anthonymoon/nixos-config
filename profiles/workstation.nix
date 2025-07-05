# Workstation Profile - Full desktop, gaming, development
{ config, lib, pkgs, inputs, user ? "amoon", ... }:

{
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
        user = user;
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

  # Gaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };
  programs.gamemode.enable = true;

  # Development tools
  environment.systemPackages = with pkgs; [
    # Desktop applications
    firefox
    thunderbird
    libreoffice
    vlc
    
    # Development
    vscode
    git
    docker
    docker-compose
    
    # Gaming
    lutris
    heroic
    
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
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
  };

  # Virtualization
  virtualisation.docker.enable = true;
  users.users.${user}.extraGroups = [ "docker" ];

  # Home manager integration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user} = { config, pkgs, lib, ... }: {
      home.stateVersion = "24.05";
      
      # Basic home configuration
      programs = {
        git = {
          enable = true;
          userName = "Anthony Moon";
          userEmail = "tonymoon@gmail.com";
        };
        
        zsh = {
          enable = true;
          oh-my-zsh = {
            enable = true;
            theme = "robbyrussell";
            plugins = [ "git" "docker" ];
          };
        };
      };
    };
  };
}