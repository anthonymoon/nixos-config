# Server Profile - Headless server services
{ config, lib, pkgs, user ? "amoon", ... }:

{
  # No desktop environment
  services.xserver.enable = false;
  
  # Server-optimized SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    openFirewall = true;
  };

  # Essential server packages
  environment.systemPackages = with pkgs; [
    # System monitoring
    htop
    iotop
    nethogs
    ncdu
    
    # Network tools
    nmap
    netcat
    tcpdump
    
    # Development/admin
    docker
    docker-compose
    tmux
    screen
    
    # File management
    rsync
    rclone
  ];

  # Server services
  services = {
    # Automatic updates
    automatic-timers.enable = true;
    
    # Log management
    journald.settings = {
      SystemMaxUse = "1G";
      MaxRetentionSec = "7day";
    };
    
    # Firewall
    fail2ban.enable = true;
  };

  # Docker for containerized services
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  users.users.${user}.extraGroups = [ "docker" ];

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
    
    # Security
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.tcp_syncookies" = 1;
  };

  # Minimal home manager for server
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user} = { config, pkgs, lib, ... }: {
      home.stateVersion = "24.05";
      
      programs = {
        git = {
          enable = true;
          userName = "Anthony Moon";
          userEmail = "tonymoon@gmail.com";
        };
        
        tmux = {
          enable = true;
          clock24 = true;
          keyMode = "vi";
        };
        
        zsh = {
          enable = true;
          oh-my-zsh = {
            enable = true;
            theme = "robbyrussell";
            plugins = [ "git" "docker" "tmux" ];
          };
        };
      };
    };
  };
}