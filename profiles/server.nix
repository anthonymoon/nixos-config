# Server Profile - Headless server with hardware support
{ config, lib, pkgs, ... }:

{
  # Hardware support - generic UEFI system
  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  # Predictable filesystem layout using labels - XFS root
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "xfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # No swap by default
  swapDevices = [ ];

  # Hardware settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # No desktop environment
  services.xserver.enable = false;
  
  # Server-optimized SSH with key-based authentication
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkForce false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
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

  # Automatic updates for security
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "/etc/nixos";
    flags = [ "--update-input" "nixpkgs" "--commit-lock-file" ];
  };

  # Server services
  services = {
    # Log management
    journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=7day
    '';
    
    # Firewall protection
    fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
    };
  };

  # Docker for containerized services
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };
  users.users.${config.myUser.username}.extraGroups = [ "docker" ];

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
    
    # Security hardening
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
  };

  # Production-ready firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];  # SSH only by default
    allowedUDPPorts = [ ];
    allowPing = false;
    logReversePathDrops = true;
  };
}