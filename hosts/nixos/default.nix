{ config, lib, pkgs, modulesPath, inputs, user, ... }:

let
  # VM Detection logic
  isVM = builtins.any (x: x) [
    (builtins.pathExists "/sys/class/dmi/id/product_name" && 
     lib.hasInfix "VMware" (builtins.readFile "/sys/class/dmi/id/product_name"))
    (builtins.pathExists "/sys/class/dmi/id/sys_vendor" && 
     lib.hasInfix "QEMU" (builtins.readFile "/sys/class/dmi/id/sys_vendor"))
    (builtins.pathExists "/sys/class/dmi/id/board_name" && 
     lib.hasInfix "VirtualBox" (builtins.readFile "/sys/class/dmi/id/board_name"))
    (builtins.pathExists "/proc/xen")
    (builtins.pathExists "/sys/bus/pci/devices/0000:00:01.1/vendor" && 
     builtins.readFile "/sys/bus/pci/devices/0000:00:01.1/vendor" == "0x80ee")
  ];
  
  # Intel X710 interface detection (for bare metal)
  hasIntelX710 = builtins.pathExists "/sys/class/net" && 
    builtins.any (iface: 
      builtins.pathExists "/sys/class/net/${iface}/device/vendor" &&
      builtins.readFile "/sys/class/net/${iface}/device/vendor" == "0x8086" &&
      builtins.pathExists "/sys/class/net/${iface}/device/device" &&
      builtins.elem (builtins.readFile "/sys/class/net/${iface}/device/device") ["0x1572" "0x1581" "0x1583"]
    ) (builtins.attrNames (builtins.readDir "/sys/class/net"));

in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")

    # Import shared configuration (tmux, zsh, packages, etc.)
    # Comment these out initially if you want to start completely minimal
    ../../modules/shared

    # Gaming modules from nix-gaming - temporarily disabled due to recursion
    # inputs.nix-gaming.nixosModules.pipewireLowLatency
    # inputs.nix-gaming.nixosModules.platformOptimizations

    # Agenix for secrets management - temporarily disabled
    # inputs.agenix.nixosModules.default
  ];

  # Hardware Configuration (merged from hardware-configuration.nix)
  boot = {
    loader.systemd-boot = {
      enable             = true;
      configurationLimit = 42;  # Limit number of generations in boot menu
    };
    loader.efi.canTouchEfiVariables = true;

    initrd.availableKernelModules = [
      "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "v4l2loopback"
    ];
    initrd.kernelModules        = [ "nvidia" ];
    kernelModules               = [ 
      "uinput"          # Input devices
      "v4l2loopback"    # Virtual cameras
      "hid_playstation" # PS5 DualSense controller
      "hid_sony"        # Sony controllers
      "xpad"            # Xbox controllers
      "nvidia-drm"      # NVIDIA DRM for KMS
    ];
    extraModulePackages         = [ pkgs.linuxPackages.v4l2loopback ];
    kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ] ++
      # Fast boot optimizations
      [ "quiet" "loglevel=3" "systemd.show_status=auto" "rd.udev.log_level=3" ] ++
      # VM-specific optimizations
      (lib.optionals isVM [
        "elevator=noop"
        "transparent_hugepage=never"
        "processor.max_cstate=1"
        "intel_idle.max_cstate=0"
      ]) ++
      # Bare metal gaming optimizations
      (lib.optionals (!isVM) [
        "preempt=full"
        "threadirqs"
        "mitigations=off"  # Disable security mitigations for performance
        "processor.max_cstate=1"
        "intel_idle.max_cstate=0"
        "intel_pstate=performance"
      ]);

    # Filesystem support
    supportedFilesystems = [ "zfs" "btrfs" "ntfs" ];
    zfs.extraPools = [ ];
  };

  # Filesystems
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3b81b6bc-b655-4985-b7dc-108ffa292c63";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device  = "/dev/disk/by-uuid/D302-2157";
    fsType  = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/d2b78e71-7ea1-472d-864a-64072cfa4978"; }
  ];

  # Hardware platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # NVIDIA drivers
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools
    ];
    extraPackages32 = with pkgs; [
      driversi686Linux.vulkan-loader
    ];
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false; # Use proprietary drivers
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaPersistenced = true; # Keep GPU initialized
    
    # Enable KMS (Kernel Mode Setting)
    forceRepaintOnResume = true;
  };

  # Gaming support with optimizations
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    # platformOptimizations.enable = true; # Disabled due to recursion
  };
  programs.gamemode.enable = true;
  
  # RGB control
  services.hardware.openrgb.enable = true;

  # Hyprland window manager
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Networking
  networking = {
    hostName = "felix";
    domain = "ad.dirtybit.co";
    nameservers = [ "94.140.14.14" "94.140.15.15" ];
    useDHCP = isVM;  # DHCP for VMs, static for bare metal
    networkmanager.enable = isVM;  # Only enable NetworkManager for VMs
    firewall.enable = false;
    
    # Bare metal static configuration
    defaultGateway = lib.mkIf (!isVM) "10.10.10.1";
    
    # Bridge configuration for bare metal
    bridges = lib.mkIf (!isVM) {
      virbr0 = {
        interfaces = [ ];  # Will be populated with X710 interface
      };
    };
    
    # Interface configuration
    interfaces = lib.mkIf (!isVM) {
      # Static IP on Intel X710 (assuming enp1s0f0 as common naming)
      enp1s0f0 = {
        ipv4.addresses = [{
          address = "10.10.10.10";
          prefixLength = 31;  # 255.255.255.254
        }];
      };
      # DHCP on other interfaces would be handled by NetworkManager when needed
    };
  };

  # Set your time zone.
  time.timeZone = "America/Kentucky/Louisville";

  # Select internationalisation properties.
  i18n.defaultLocale      = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  # Enable the X11 windowing system (still needed for compatibility).
  # Enable the KDE Plasma Desktop Environment with Wayland.
  services = {
    xserver = {
      enable = true;

      # Configure keymap
      xkb = {
        layout  = "us";
        variant = "";
      };
    };

    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;  # Enable Wayland support in SDDM
      };

      # Enable automatic login for the user.
      autoLogin = {
        enable = true;
        inherit user;
      };

      # Set default session to Hyprland
      defaultSession = "hyprland";
    };

    # KDE Plasma 6 desktop
    desktopManager.plasma6.enable = true;



    # Enable sound with PipeWire (PulseAudio disabled in favor of PipeWire).
    pulseaudio.enable = false;

    pipewire = {
      enable           = true;
      alsa.enable      = true;
      alsa.support32Bit = true;
      pulse.enable     = true;
      # lowLatency = {
      #   enable = true;
      #   quantum = 64;
      #   rate = 48000;
      # }; # Disabled due to recursion
      # If you want to use JACK applications, uncomment:
      # jack.enable = true;
      # use the example session manager:
      # media-session.enable = true;
    };
    
    # Make pipewire realtime-capable
    rtkit.enable = true;

    # Enable touchpad support (enabled by default in most desktopManager).
    # xserver.libinput.enable = true;

    # Enable the OpenSSH daemon.
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "yes";
        Port = 22;
      };
      openFirewall = true;
    };

    # Snapper for filesystem snapshots - disabled for fast boot
    snapper.enable = false;

    # Media services - only on bare metal
    jellyfin = {
      enable = !isVM;
      openFirewall = !isVM;
      user = "jellyfin";
      group = "jellyfin";
    };

    # Samba file sharing - only on bare metal
    samba = lib.mkIf (!isVM) {
      enable = true;
      securityType = "user";
      openFirewall = true;
      extraConfig = ''
        workgroup = WORKGROUP
        server string = NixOS Samba Server
        netbios name = felix
        security = user
        map to guest = bad user
        guest account = nobody
      '';
      shares = {
        public = {
          path = "/home/${user}/Public";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
        };
      };
    };

    # Virtualization with libvirtd - disabled, moved to virtualisation section

    # *arr stack media management - only on bare metal
    sonarr = {
      enable = !isVM;
      openFirewall = !isVM;
      user = "sonarr";
      group = "media";
    };

    radarr = {
      enable = !isVM;
      openFirewall = !isVM;
      user = "radarr";
      group = "media";
    };

    lidarr = {
      enable = !isVM;
      openFirewall = !isVM;
      user = "lidarr";
      group = "media";
    };

    prowlarr = {
      enable = !isVM;
      openFirewall = !isVM;
    };

    bazarr = {
      enable = !isVM;
      openFirewall = !isVM;
      user = "bazarr";
      group = "media";
    };

    jackett = {
      enable = !isVM;
      openFirewall = !isVM;
      user = "jackett";
      group = "media";
    };

    # System monitoring - only on bare metal
    netdata = {
      enable = !isVM;
      config = {
        global = {
          "default port" = "19999";
          "bind to" = "*";
        };
      };
    };

    # Web server - only on bare metal
    nginx = {
      enable = !isVM;
      openFirewall = !isVM;
    };

    # Music Player Daemon - only on bare metal
    mpd = {
      enable = !isVM;
      user = user;
      musicDirectory = "/home/${user}/Music";
      extraConfig = ''
        audio_output {
          type "pipewire"
          name "PipeWire Sound Server"
        }
      '';
    };

    # Network discovery - only on bare metal
    avahi = {
      enable = !isVM;
      nssmdns4 = !isVM;
      openFirewall = !isVM;
      publish = {
        enable = !isVM;
        addresses = !isVM;
        workstation = !isVM;
      };
    };

    # Windows Service Discovery - only on bare metal
    wsdd = {
      enable = !isVM;
      openFirewall = !isVM;
    };

    # System Security Services Daemon - disabled for fast boot
    sssd.enable = false;

    # Jellyseerr media request management - only on bare metal
    jellyseerr = {
      enable = !isVM;
      openFirewall = !isVM;
    };

    # Vaultwarden password manager - disabled for fast boot
    vaultwarden.enable = false;

    # Autofs for automatic mounting - only on bare metal
    autofs = lib.mkIf (!isVM) {
      enable = true;
      autoMaster = ''
        /net -hosts --timeout=60
        /mnt/auto /etc/auto.misc --timeout=60
      '';
    };

    # PostgreSQL database - disabled for fast boot
    postgresql.enable = false;

    # Security - Fail2ban - disabled for fast boot
    fail2ban.enable = false;

    # Syncthing for file synchronization - disabled for fast boot
    syncthing.enable = false;

    # NFS Server - only on bare metal
    nfs.server = lib.mkIf (!isVM) {
      enable = true;
      exports = ''
        /srv/nfs         192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
        /home/${user}/Public  192.168.1.0/24(rw,sync,no_subtree_check)
      '';
      # Create a stable NFS state directory
      statdPort = 4000;
      lockdPort = 4001;
      mountdPort = 4002;
    };

    # AdGuard Home - DNS ad blocker - disabled for fast boot
    adguardhome.enable = false;

    # Smokeping network latency monitoring - disabled for fast boot
    smokeping.enable = false;

    # ClamAV antivirus - disabled for fast boot
    clamav = {
      daemon.enable = false;
      updater.enable = false;
    };
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.${user} = {
    isNormalUser = true;
    description  = "Anthony Moon";
    extraGroups  = [ "networkmanager" "wheel" "libvirtd" "media" "docker" ];
    shell = pkgs.zsh;
  };

  # Define media group for arr stack
  users.groups.media = {};

  # Install firefox.
  programs.firefox.enable = true;

  # My shell
  programs.zsh.enable = true;
  
  # Additional shells
  programs.fish.enable = true;
  
  # Flatpak support
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Virtualization support - conditional
  virtualisation = {
    libvirtd.enable = !isVM;  # Disable libvirtd in VMs
    spiceUSBRedirection.enable = !isVM;
    docker = {
      enable = true;
      enableOnBoot = !isVM;  # Only auto-start on bare metal
      autoPrune.enable = true;
    };
  };

  # System optimizations
  boot.kernel.sysctl = {
    # Common optimizations
    "kernel.sysrq" = 1;
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 65536 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;
  } // 
  # VM-specific optimizations
  (lib.optionalAttrs isVM {
    "vm.swappiness" = 1;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "vm.dirty_expire_centisecs" = 1500;
    "vm.dirty_writeback_centisecs" = 500;
    "kernel.timer_migration" = 0;
  }) //
  # Bare metal high-performance server optimizations
  (lib.optionalAttrs (!isVM) {
    # Filesystem optimizations
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 1048576;
    
    # Kernel security & performance
    "kernel.kptr_restrict" = 2;
    "kernel.perf_event_paranoid" = 3;
    "kernel.unprivileged_bpf_disabled" = 1;
    "kernel.randomize_va_space" = 2;
    "kernel.sched_autogroup_enabled" = 0;
    "kernel.numa_balancing" = 0;
    "kernel.shmmax" = 68719476736;
    "kernel.shmall" = 16777216;
    "kernel.msgmax" = 65536;
    "kernel.msgmni" = 32768;
    
    # Network core optimizations
    "net.core.bpf_jit_enable" = 1;
    "net.core.bpf_jit_harden" = 0;
    "net.core.rmem_default" = 67108864;
    "net.core.rmem_max" = 1073741824;
    "net.core.wmem_default" = 67108864;
    "net.core.wmem_max" = 1073741824;
    "net.core.netdev_max_backlog" = 500000;
    "net.core.netdev_budget" = 8000;
    "net.core.netdev_budget_usecs" = 100000;
    "net.core.busy_read" = 50;
    "net.core.busy_poll" = 50;
    "net.core.somaxconn" = 262144;
    "net.core.optmem_max" = 134217728;
    "net.core.default_qdisc" = "fq";
    
    # TCP optimizations
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_rmem" = "65536 16777216 1073741824";
    "net.ipv4.tcp_wmem" = "65536 16777216 1073741824";
    "net.ipv4.tcp_mem" = "16777216 33554432 268435456";
    "net.ipv4.tcp_max_syn_backlog" = 262144;
    "net.ipv4.tcp_max_tw_buckets" = 16000000;
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_fack" = 1;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_fin_timeout" = 10;
    "net.ipv4.tcp_keepalive_time" = 120;
    "net.ipv4.tcp_keepalive_probes" = 3;
    "net.ipv4.tcp_keepalive_intvl" = 10;
    "net.ipv4.tcp_retries1" = 2;
    "net.ipv4.tcp_retries2" = 5;
    "net.ipv4.tcp_synack_retries" = 2;
    "net.ipv4.tcp_syn_retries" = 2;
    "net.ipv4.tcp_adv_win_scale" = 2;
    "net.ipv4.tcp_moderate_rcvbuf" = 1;
    "net.ipv4.tcp_frto" = 2;
    "net.ipv4.tcp_low_latency" = 1;
    "net.ipv4.tcp_ecn" = 2;
    "net.ipv4.ip_local_port_range" = "1024 65535";
    
    # ARP table scaling
    "net.ipv4.neigh.default.gc_thresh1" = 4096;
    "net.ipv4.neigh.default.gc_thresh2" = 8192;
    "net.ipv4.neigh.default.gc_thresh3" = 16384;
    
    # Security settings
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    
    # IPv6 optimizations
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.default.autoconf" = 0;
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.default.accept_ra" = 0;
    
    # Virtual memory optimizations for 128GB system
    "vm.swappiness" = 1;
    "vm.dirty_ratio" = 40;
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
    "vm.max_map_count" = 262144;
    "vm.min_free_kbytes" = 131072;
    "vm.nr_hugepages" = 8192;
    "vm.hugetlb_shm_group" = 0;
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 80;
    "vm.zone_reclaim_mode" = 0;
  });

  # List packages installed in system profile. To search, run:
  #   $ nix search <pkg>
  environment.systemPackages = with pkgs; [
    vim
    git
    # Wayland-specific utilities
    wl-clipboard     # Wayland clipboard utilities (replaces xclip)
    wayland-utils    # Wayland utilities
    # inputs.agenix.packages."${pkgs.system}".default  # agenix CLI (temporarily disabled)
    
    # Gaming packages from nix-gaming - temporarily disabled due to recursion
    # inputs.nix-gaming.packages.${pkgs.system}.dxvk-nvapi
    # inputs.nix-gaming.packages.${pkgs.system}.vkd3d-proton
    # inputs.nix-gaming.packages.${pkgs.system}.wine-mono
    # inputs.nix-gaming.packages.${pkgs.system}.wineprefix-preparer
    # Try winetricks-git first, fallback to standard winetricks
    # (inputs.nix-gaming.packages.${pkgs.system}.winetricks-git or winetricks)
    wine-staging  # Keep standard wine
    dxvk          # Keep standard dxvk as fallback
  ];

  # Default applications and environment
  environment.sessionVariables = {
    TERMINAL = "terminator";
    BROWSER = "microsoft-edge";
    FILEMANAGER = "thunar";
  };

  # XDG default applications
  environment.etc."xdg/mimeapps.list".text = ''
    [Default Applications]
    application/pdf=okular.desktop
    text/html=microsoft-edge.desktop
    x-scheme-handler/http=microsoft-edge.desktop
    x-scheme-handler/https=microsoft-edge.desktop
    x-scheme-handler/about=microsoft-edge.desktop
    x-scheme-handler/unknown=microsoft-edge.desktop
    inode/directory=thunar.desktop
    application/vnd.oasis.opendocument.text=libreoffice-writer.desktop
    application/vnd.oasis.opendocument.spreadsheet=libreoffice-calc.desktop
    application/vnd.oasis.opendocument.presentation=libreoffice-impress.desktop
    application/msword=libreoffice-writer.desktop
    application/vnd.ms-excel=libreoffice-calc.desktop
    application/vnd.ms-powerpoint=libreoffice-impress.desktop
    x-scheme-handler/mailto=thunderbird.desktop
  '';

  # Enable Diodon clipboard manager
  services.diodon.enable = true;

  # Boot optimizations
  systemd = {
    # Reduce default timeouts for faster boot
    extraConfig = ''
      DefaultTimeoutStartSec=10s
      DefaultTimeoutStopSec=5s
      DefaultRestartSec=1s
      DefaultLimitNOFILE=1048576
    '';
    
    # Disable unnecessary services for fast boot
    services = {
      "systemd-random-seed".enable = false;
      "systemd-timesyncd".enable = false;  # Will use chrony instead if needed
    };
    
    user.extraConfig = ''
      DefaultTimeoutStartSec=10s
      DefaultTimeoutStopSec=5s
    '';
  };

  # Additional VM/Bare metal optimizations
  powerManagement = {
    enable = !isVM;  # Disable power management in VMs
    cpuFreqGovernor = lib.mkIf (!isVM) "performance";
  };

  # Tuned profiles
  services.tuned = {
    enable = true;
    profile = if isVM then "virtual-guest" else "latency-performance";
  };

  # KVM modprobe configurations for bare metal
  boot.extraModprobeConfig = lib.mkIf (!isVM) ''
    # KVM base module parameters
    options kvm ignore_msrs=1
    options kvm report_ignored_msrs=0
    options kvm halt_poll_ns=1000000
    options kvm halt_poll_ns_grow=2
    options kvm halt_poll_ns_shrink=0

    # KVM Intel module parameters for virtualization performance
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

    # VFIO module parameters for PCIe passthrough
    options vfio_iommu_type1 allow_unsafe_interrupts=0
    options vfio_pci disable_vga=0
    options vfio_iommu_type1 disable_hugepages=0
  '';

  # Don't require password for users in `wheel` group
  security.sudo = {
    enable     = true;
    extraRules = [
      {
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
        users = [ user ];
      }
    ];
  };

  # Fonts
  fonts.packages = import ../../modules/shared/fonts.nix { inherit pkgs; };

  # Configure Nix settings for flakes and Cachix
  nix = {
    nixPath = [
      "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos"
    ];
    settings = {
      allowed-users       = [ "${user}" ];
      trusted-users       = [ "@admin" "${user}" "root" ];
      substituters        = [
        "https://nix-community.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      ];
      experimental-features = [ "nix-command" "flakes" ];
    };
    package      = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # This value determines the NixOS release from which default
  # settings for stateful data were taken. Leave it at your first
  # install's release unless you know what you're doing.
  system.stateVersion = "25.05";
}
