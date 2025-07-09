# Server Profile - Headless server with hardware support
{ config, lib, pkgs, username, ... }:

{
  imports = [
    ../modules/media-server.nix
  ];
  # Media server is optional - enable with: modules.media-server.enable = true;
  
  # Filesystem configuration handled by Disko
  # No swap devices - using ZRAM from base profile
  # Hardware configuration handled by universal kernel module

  # Platform settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  
  # Server-specific kernel tuning (override defaults from kernel module)
  powerManagement.cpuFreqGovernor = lib.mkForce "performance";

  # No desktop environment
  services.xserver.enable = false;
  
  # SSH configuration handled in common.nix

  # Essential server packages
  environment.systemPackages = with pkgs; [
    # System monitoring
    iotop
    nethogs
    ncdu
    
    # Network tools
    nmap
    netcat
    tcpdump
    
    # Administration tools
    tmux
    screen
    
    # File management
    rsync
    rclone
  ];

  # Automatic updates for security. Disabled by default in server profile
  # due to flake path constraints in pure evaluation mode. If enabling,
  # ensure the flake path is correctly set and accessible, e.g., by copying
  # the flake to /etc/nixos or using a persistent path.
  system.autoUpgrade = {
    enable = lib.mkForce false;
    allowReboot = false;
    # flake = "/etc/nixos"; # Example: Uncomment and adjust if flake is copied to /etc/nixos
    flags = [ "--update-input" "nixpkgs" "--commit-lock-file" ];
  };

  # Server services
  services = {
    # Log management
    journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=7day
    '';
  };

  # Docker for containerized services
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };
  # Add the user to docker group only if username is provided
  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    nixos = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    amoon = {
      isNormalUser = true;
      extraGroups = [ "wheel" "docker" ]; # Add amoon to docker group
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
  } // lib.mkIf (username != null) { ${username}.extraGroups = [ "docker" ]; };

  # Server performance optimizations
  boot.kernel.sysctl = {
    # Network optimizations
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 65536 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    
    # File system optimizations
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 524288;
  };

  
  
  # Production-ready firewall configuration
  networking.firewall.enable = false;

  # Server-specific directory setup
  systemd.tmpfiles.rules = [
    "d /var/log/custom 0755 root root -"
    "d /opt/scripts 0755 root root -"
  ];

  # Custom log rotation for server logs
  services.logrotate.settings = {
    "/var/log/custom/*.log" = {
      frequency = "daily";
      rotate = 52;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "644 root root";
    };
  };
}