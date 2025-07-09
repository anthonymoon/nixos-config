# Server Profile - Headless server with hardware support
{ config, lib, pkgs, username, ... }:

{
  imports = [
    ../modules/media-server.nix
  ];
  # Media server is optional - enable with: modules.media-server.enable = true;
  
  # Home Manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.amoon = import ../home-manager/default.nix;
  };
  
  # Filesystem configuration handled by Disko
  # No swap devices - using ZRAM from base profile
  # Hardware configuration handled by universal kernel module

  # Platform settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  
  # Server-specific kernel tuning (override defaults from kernel module)
  powerManagement.cpuFreqGovernor = lib.mkForce "performance";
  
  # Kernel modules and boot configuration
  boot = {
    # Kernel modules to load early
    kernelModules = [ "crc32c" "nvme" "ahci" "xhci_hcd" "br_netfilter" "vfio-pci" ];
    
    # Kernel parameters from GRUB configuration
    kernelParams = [
      "apparmor=0"
      "cryptomgr.notests"
      "elevator=none"
      "fastboot"
      "i40e.enable_sw_lldp=0"
      "intel_iommu=on"
      "iommu=pt"
      "kvm_intel.nested=1"
      "loglevel=3"
      "mitigations=off"
      "nowatchdog"
      "nvidia-drm.modeset=1"
      "nvme_core.default_ps_max_latency_us=0"
      "pci=realloc=on"
      "pcie_aspm=off"
      "quiet"
      "random.trust_cpu=on"
      "rd.udev.log_level=3"
      "scsi_mod.use_blk_mq=1"
      "splash"
      "tsc=reliable"
      "zfs.zfs_autoimport_disable=0"
      "zswap.enabled=0"
    ];
    
    # Initrd configuration
    initrd = {
      availableKernelModules = [ "nvme" "ahci" "xhci_hcd" "crc32c" ];
      kernelModules = [ "crc32c" "nvme" "ahci" "xhci_hcd" ];
      compressor = "lz4";
    };
    
    # Bootloader configuration
    loader = {
      grub = {
        enable = true;
        device = "/dev/sda"; # Adjust this for your system
        useOSProber = true;
        extraConfig = ''
          GRUB_TERMINAL_INPUT=console
          GRUB_GFXMODE=auto
          GRUB_GFXPAYLOAD_LINUX=keep
          GRUB_DISABLE_RECOVERY=true
        '';
      };
      timeout = 5;
    };
  };
  
  # Kernel module options (modprobe.d equivalent)
  boot.extraModprobeConfig = ''
    # Network blacklist
    blacklist b43
    blacklist b43legacy
    blacklist ssb
    blacklist bcm43xx
    blacklist brcm80211
    blacklist brcmfmac
    blacklist brcmsmac
    blacklist bcma
    
    # GPU blacklist
    blacklist nouveau
    blacklist amdgpu
    blacklist radeon
    blacklist nvidia
    
    # KVM configuration
    options kvm ignore_msrs=1
    options kvm report_ignored_msrs=0
    options kvm halt_poll_ns=1000000
    options kvm halt_poll_ns_grow=2
    options kvm halt_poll_ns_shrink=0
    
    # KVM Intel configuration
    options kvm_intel nested=1
    options kvm_intel enable_apicv=1
    options kvm_intel ept=1
    options kvm_intel vpid=1
    options kvm_intel pml=1
    options kvm_intel unrestricted_guest=1
    options kvm_intel flexpriority=1
    options kvm_intel enable_shadow_vmcs=1
    options kvm_intel ple_gap=128
    options kvm_intel ple_window=4096
    options kvm_intel preemption_timer=1
    
    # VFIO configuration
    options vfio_iommu_type1 allow_unsafe_interrupts=0
    options vfio_pci disable_vga=0
    options vfio_iommu_type1 disable_hugepages=0
    options vfio-pci ids=10de:1b80,10de:10f0
    
    # Truescale configuration
    install ib_qib modprobe -i ib_qib $CMDLINE_OPTS && /usr/lib/rdma/truescale-serdes.cmds start
  '';

  # No desktop environment, but use greetd for login
  services.xserver.enable = false;
  
  # Display manager - greetd with tui-greeter
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd zsh";
        user = "greeter";
      };
    };
  };
  
  # SSH configuration handled in common.nix

  # Essential server packages - based on Arch Linux system
  environment.systemPackages = with pkgs; [
    # System monitoring
    iotop
    nethogs
    ncdu
    btop
    htop
    sysstat
    smartmontools
    nvme-cli
    
    # Network tools
    nmap
    netcat
    tcpdump
    socat
    samba
    openssh
    wireshark
    
    # Administration tools
    screen
    strace
    perf
    zellij
    multitail
    mosh
    
    # File management
    rsync
    rclone
    tree
    plocate
    
    # Development tools
    git
    vim
    neovim
    ripgrep
    vscode-insiders
    
    # Shell utilities
    fish
    zsh
    bash-completion
    which
    
    # Archive tools
    zip
    unzip
    unrar
    
    # System utilities
    usbutils
    pciutils
    bc
    
    
    # Infrastructure tools
    ansible
    terraform
    
    # Build tools
    python3
    python3Packages.pip
    nodejs
    npm
    
    # Cloud tools
    awscli
    
    # Text processing
    perl
    
    # Package management
    nix-search-cli
    
    # System administration
    sudo
    
    # Networking
    wget
    curl
    bind
    
    # Filesystem tools
    xfsprogs
    btrfs-progs
    
    # Container tools (Docker configured separately)
    
    # Performance tools
    pv
    
    # System services
    systemd
    
    # Database tools
    sqlite
    
    # Monitoring
    prometheus
    grafana
    
    # Web tools
    nginx
    
    # Time synchronization
    ntp
    
    # Text editors
    nano
    
    # Terminal utilities
    kitty
    ghostty
    konsole
    
    # Display manager
    greetd.tuigreet
    
    # Font support
    dejavu_fonts
    liberation_ttf
    
    # Audio support (minimal for server)
    alsa-utils
    
    # Bluetooth support
    bluez
    bluez-tools
    
    # Development languages
    rustc
    cargo
    
    # System backup
    # timeshift
    
    # Shell enhancements
    zoxide
    
    # Code quality
    shellcheck
    
    # Package building
    dpkg
    
    # System tuning
    # tuned
    
    # Network management
    # networkmanager
    
    # DNS tools
    dnsutils
    
    # Log analysis
    logrotate
    
    # Process management
    htop
    
    # System information
    fastfetch
    
    
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
    
    # SSH service (configured in common.nix)
    openssh.enable = true;
    
    # Network time synchronization
    ntp.enable = true;
    
    # System monitoring
    prometheus = {
      enable = true;
      port = 9090;
    };
    
    # Web server for monitoring
    nginx = {
      enable = true;
      statusPage = true;
    };
    
    # Samba/SMB configuration
    samba = {
      enable = true;
      securityType = "user";
      extraConfig = ''
        # Optimized Samba configuration for 1GbE network and Time Machine
        workgroup = WORKGROUP
        netbios name = CACHY
        
        bind interfaces only = yes
        interfaces = virbr0
        
        # Protocol optimization - Use latest SMB3 with all features
        server min protocol = SMB3_00
        server max protocol = SMB3_11
        client min protocol = SMB3_00  
        client max protocol = SMB3_11
        
        # Security - Disable signing for maximum performance (LAN only)
        server signing = disabled
        client signing = disabled
        
        # SMB3 Multichannel - CRITICAL for 10GbE performance  
        server multi channel support = yes
        # SMB3 Encryption with GnuTLS (3x performance improvement)
        smb encrypt = desired
        server smb encrypt = desired
        
        # Modern I/O optimizations
        use sendfile = yes
        aio read size = 16384
        aio write size = 16384
        aio write behind = yes
        
        # Memory and locking optimizations
        kernel oplocks = no
        level2 oplocks = yes
        oplocks = yes
        strict locking = no
        
        # Connection management
        deadtime = 15
        max smbd processes = 0
        
        # Time Machine optimizations
        min receivefile size = 16384
        getwd cache = yes
        
        # Logging (minimal for performance)
        log level = 10
        max log size = 1000
        
        # Case sensitivity optimization for large directories
        case sensitive = true
        default case = lower
        preserve case = no
        short preserve case = no
        
        # ZFS-specific optimizations
        strict allocate = no
      '';
      shares = {
        storage = {
          path = "/storage";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "@sambausers";
          "create mask" = "0664";
          "directory mask" = "0775";
          "force create mode" = "0664";
          "force directory mode" = "0775";
          "vfs objects" = "zfsacl";
          "nfs4:mode" = "special";
          "nfs4:acedup" = "merge";
          "nfs4:chown" = "yes";
        };
        media = {
          path = "/storage/media";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "@sambausers";
          "create mask" = "0664";
          "directory mask" = "0775";
          "use sendfile" = "yes";
          "strict allocate" = "no";
        };
        VMs = {
          path = "/storage/VMs";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "@sambausers";
          "create mask" = "0664";
          "directory mask" = "0775";
          "strict allocate" = "no";
        };
        TimeMachine = {
          path = "/storage/timemachine";
          comment = "Time Machine Backup";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "@sambausers";
          "create mask" = "0664";
          "directory mask" = "0775";
          "force create mode" = "0664";
          "force directory mode" = "0775";
          "vfs objects" = "fruit streams_xattr";
          "fruit:time machine" = "yes";
          "fruit:time machine max size" = "2T";
          "allocation roundup size" = "1048576";
          "min receivefile size" = "16384";
          "kernel oplocks" = "no";
          "posix locking" = "no";
          "strict locking" = "no";
          "dos filetimes" = "yes";
          "dos filetime resolution" = "yes";
          "case sensitive" = "no";
          "preserve case" = "yes";
          "vfs:fruit debug" = "yes";
          "log file" = "/var/log/samba/timemachine.log";
        };
      };
    };
    
    # Database
    postgresql = {
      enable = true;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        local all all trust
        host all all 127.0.0.1/32 trust
        host all all ::1/128 trust
      '';
    };
    
    # Redis database
    redis = {
      servers."" = {
        enable = true;
        port = 6379;
      };
    };
    
    
    # System tuning
    # tuned = {
    #   enable = true;
    #   profile = "server";
    # };
    
    
    # Bluetooth support
    blueman.enable = true;
    
    # Audio support (minimal for server)
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    
    # DNS resolution
    resolved.enable = true;
    
    # Time synchronization
    timesyncd.enable = true;
    
    # System backup (timeshift) - configured but not scheduled
    # timeshift = {
    #   enable = true;
    #   # Match current configuration - no automatic scheduling
    #   autosnap = false;
    # };
    
    # Log rotation
    logrotate.enable = true;
    
    # System statistics
    sysstat.enable = true;
    
    # Smart monitoring
    smartd.enable = true;
    
    # USB automount
    udisks2.enable = true;
    
    # Power management
    upower.enable = true;
    
    # Location services
    geoclue2.enable = true;
    
    # Firmware updates
    fwupd.enable = true;
    
    # XDG user directories
    xserver.desktopManager.xterm.enable = false;
    
    # Avahi service discovery
    avahi = {
      enable = true;
      nssmdns = true;
      publish = {
        enable = true;
        addresses = true;
        hinfo = false;
        workstation = false;
        domain = true;
      };
      extraConfig = ''
        [server]
        use-ipv4=yes
        use-ipv6=yes
        ratelimit-interval-usec=1000000
        ratelimit-burst=1000
        
        [wide-area]
        enable-wide-area=yes
        
        [publish]
        publish-hinfo=no
        publish-workstation=no
        
        [reflector]
        
        [rlimits]
      '';
    };
  };

  # Docker for containerized services
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };
  # Users and groups configuration matching current system
  users.groups = {
    sambausers = {
      gid = 1002;
    };
    sys = {
      gid = 3;
    };
    network = {
      gid = 90;
    };
    scanner = {
      gid = 96;
    };
    wheel = {
      gid = 998;
    };
    audio = {
      gid = 996;
    };
    input = {
      gid = 994;
    };
    kvm = {
      gid = 992;
    };
    lp = {
      gid = 991;
    };
    optical = {
      gid = 990;
    };
    storage = {
      gid = 987;
    };
    video = {
      gid = 985;
    };
    users = {
      gid = 984;
    };
    systemd-journal = {
      gid = 982;
    };
    rfkill = {
      gid = 981;
    };
    libvirt = {
      gid = 960;
    };
    docker = {
      gid = 958;
    };
    wireshark = {
      gid = 150;
    };
  };
  
  users.users = {
    root = {
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    nixos = {
      isNormalUser = true;
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    amoon = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ 
        "wheel" 
        "docker"
        "sys"
        "network"
        "audio"
        "kvm"
        "lp"
        "storage"
        "video"
        "users"
        "rfkill"
        "libvirtd"
        "libvirt-qemu"
        "wireshark"
        "sambausers"
        "scanner"
        "optical"
        "input"
        "systemd-journal"
      ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
  } // lib.mkIf (username != null) { ${username}.extraGroups = [ "docker" ]; };
  
  # Enable ZSH as system shell
  programs.zsh.enable = true;
  programs.fish.enable = true;
  
  # Sudo configuration matching current system
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
    configFile = ''
      ## Defaults specification
      Defaults!/usr/bin/visudo env_keep += "SUDO_EDITOR EDITOR VISUAL"
      Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/bin"
      
      ## User privilege specification
      root ALL=(ALL:ALL) ALL
      
      ## Allow members of group wheel to execute any command
      %wheel ALL=(ALL:ALL) ALL
      
      ## Passwordless sudo for amoon user
      amoon ALL=(ALL) NOPASSWD: ALL
    '';
  };
  
  # Enable bluetooth
  hardware.bluetooth.enable = true;
  
  # Enable sound with PipeWire
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  
  # Enable virtualization
  virtualisation.libvirtd.enable = true;
  
  # Enable printer support
  services.printing.enable = true;
  
  # Enable scanner support
  hardware.sane.enable = true;
  
  # Enable Wireshark for network analysis
  programs.wireshark.enable = true;

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

  
  
  # Network configuration
  networking = {
    firewall.enable = false;
    hostName = "cachy";
    domain = "local";
    
    # Custom hosts file entries
    hosts = {
      "127.0.0.1" = [ "localhost" ];
      "10.10.10.10" = [ "cachy" "cachy.local" ];
      # IPv6 localhost commented out since IPv6 is disabled in current config
    };
    
    # Name service switch configuration
    nameservers = [ "127.0.0.53" ];
    
    # Use systemd-networkd for network management
    useNetworkd = true;
    useDHCP = false;
  };
  
  # SystemD network configuration
  systemd.network = {
    enable = true;
    
    # Network devices
    netdevs = {
      "30-virbr0" = {
        netdevConfig = {
          Name = "virbr0";
          Kind = "bridge";
        };
        bridgeConfig = {
          STP = true;
          Priority = 32768;
          HelloTimeSec = 1;
          ForwardDelaySec = 2;
          MaxAgeSec = 4;
          MulticastQuerier = true;
        };
      };
      
      "40-libvirt0" = {
        netdevConfig = {
          Name = "libvirt0";
          Kind = "bridge";
        };
        bridgeConfig = {
          STP = false;
          DefaultPVID = 1;
        };
      };
    };
    
    # Network configurations
    networks = {
      "10-onboard-eth" = {
        matchConfig = {
          MACAddress = "1c:b7:2c:ef:d0:a5";
          Name = "eth0 eno1";
        };
        networkConfig = {
          DHCP = "yes";
          MulticastDNS = false;
        };
        dhcpV4Config = {
          RouteMetric = 300;
        };
        linkConfig = {
          RequiredForOnline = false;
        };
      };
      
      "20-intel-x710-p0" = {
        matchConfig = {
          MACAddress = "f8:f2:1e:14:38:44";
          Name = "eth1 ens* enp*";
        };
        networkConfig = {
          Bridge = "virbr0";
          LLDP = true;
          EmitLLDP = true;
        };
        linkConfig = {
          RequiredForOnline = false;
        };
      };
      
      "21-intel-x710-p1" = {
        matchConfig = {
          MACAddress = "f8:f2:1e:14:38:46";
          Name = "eth2 ens* enp*";
        };
        networkConfig = {
          Bridge = "virbr0";
          LLDP = true;
          EmitLLDP = true;
        };
        linkConfig = {
          RequiredForOnline = false;
        };
      };
      
      "30-virbr0" = {
        matchConfig = {
          Name = "virbr0";
        };
        networkConfig = {
          Address = "10.10.10.10/23";
          Gateway = "10.10.10.1";
          DNS = [ "94.140.14.14" "94.140.15.15" ];
          IPForward = "ipv4";
          IPMasquerade = "ipv4";
          LLDP = true;
          EmitLLDP = true;
          DHCP = false;
          MulticastDNS = false;
          LinkLocalAddressing = false;
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
        };
        linkConfig = {
          RequiredForOnline = true;
          BindCarrier = [ "eth1" "eth2" ];
        };
        routes = [
          {
            routeConfig = {
              Gateway = "10.10.10.1";
              Metric = 10;
              GatewayOnLink = true;
            };
          }
        ];
      };
      
      "40-libvirt0" = {
        matchConfig = {
          Name = "libvirt0";
        };
        networkConfig = {
          Address = "192.168.100.1/24";
          IPForward = "ipv4";
          IPMasquerade = "ipv4";
          DHCP = false;
          MulticastDNS = false;
          LinkLocalAddressing = false;
          IPv6AcceptRA = false;
        };
        linkConfig = {
          RequiredForOnline = false;
        };
      };
    };
  };
  
  # NSS configuration matching current system
  system.nssModules = with pkgs; [ nss-mdns ];
  system.nssDatabases = {
    passwd = [ "files" "systemd" ];
    group = [ "files" "systemd" ];
    shadow = [ "files" "systemd" ];
    hosts = [ "mymachines" "resolve" "files" "myhostname" "dns" ];
    networks = [ "files" ];
    protocols = [ "files" ];
    services = [ "files" ];
  };

  # Server-specific directory setup
  systemd.tmpfiles.rules = [
    "d /var/log/custom 0755 root root -"
    "d /opt/scripts 0755 root root -"
    "d /storage 0755 root root -"
    "d /storage/media 0755 root root -"
    "d /storage/VMs 0755 root root -"
    "d /storage/timemachine 0755 root root -"
    "d /var/log/samba 0755 root root -"
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