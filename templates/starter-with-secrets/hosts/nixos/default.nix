{ config, inputs, pkgs, agenix, ... }:

let user = "%USER%";
    keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOk8iAnIaa1deoc7jw8YACPNVka1ZFJxhnU4G74TmS+p" ]; in
{
  imports = [
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/disk-config.nix
    ../../modules/shared
    agenix.nixosModules.default
  ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 42;
      };
      efi.canTouchEfiVariables = true;
    };
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
    # Uncomment for AMD GPU
    # initrd.kernelModules = [ "amdgpu" ];
    kernelPackages = pkgs.linuxPackages_latest.extend (final: prev: {
      kernel = prev.kernel.override {
        stdenv = pkgs.stdenvAdapters.withCFlags [ "-march=x86-64-v3" ] pkgs.stdenv;
        structuredExtraConfig = with pkgs.lib.kernel; {
          # Enable sched-ext extensible scheduler framework
          SCHED_CLASS_EXT = yes;
          # Enable BPF scheduler support
          BPF_SYSCALL = yes;
          BPF_JIT = yes;
          # Optimize for x86-64-v3 (AVX, AVX2, BMI1, BMI2, F16C, FMA, LZCNT, MOVBE, XSAVE)
          MHASWELL = yes;
        };
      };
    });
    kernelModules = [ "uinput" ];
    # Kernel parameters for NVMe/SSD optimization and performance
    kernelParams = [
      "scsi_mod.use_blk_mq=1"  # Enable multi-queue block layer for SCSI
      "elevator=noop"          # Use noop I/O scheduler for SSDs
      "mitigations=off"        # Disable CPU vulnerability mitigations for max performance
      "intel_iommu=on"         # Enable Intel IOMMU for virtualization
      "iommu=pt"               # IOMMU passthrough mode for better performance
      "cryptomgr.notests"      # Skip crypto self-tests for faster boot
      "random.trust_cpu=on"    # Trust CPU RNG for faster entropy
      "pci=realloc=on"         # Enable PCI BAR reallocation
    ];
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # System-wide sysctl optimizations
  boot.kernel.sysctl = {
    # === FILESYSTEM OPTIMIZATIONS ===
    # Increase for high I/O workloads (current systems need more)
    "fs.file-max" = 2097152;
    # Optimal for containers/monitoring
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 1048576;

    # === KERNEL SECURITY & PERFORMANCE ===
    # Security hardening
    "kernel.kptr_restrict" = 2;
    "kernel.perf_event_paranoid" = 3;
    "kernel.unprivileged_bpf_disabled" = 1;
    "kernel.randomize_va_space" = 2;
    "kernel.sysrq" = 0;

    # Performance optimizations
    "kernel.sched_autogroup_enabled" = 0;
    "kernel.numa_balancing" = 0;

    # Memory management (VM appropriate values)
    "kernel.shmmax" = 8589934592;  # 8GB instead of 64GB
    "kernel.shmall" = 2097152;     # Reduced from 16M
    "kernel.msgmax" = 65536;
    "kernel.msgmni" = 32768;

    # === NETWORK CORE OPTIMIZATIONS ===
    # BPF optimizations
    "net.core.bpf_jit_enable" = 1;
    "net.core.bpf_jit_harden" = 0;

    # High-performance networking (VM appropriate values)
    "net.core.rmem_default" = 16777216;   # 16MB instead of 64MB
    "net.core.rmem_max" = 134217728;      # 128MB instead of 1GB
    "net.core.wmem_default" = 16777216;   # 16MB instead of 64MB
    "net.core.wmem_max" = 134217728;      # 128MB instead of 1GB

    # Packet processing (VM appropriate values)
    "net.core.netdev_max_backlog" = 50000;   # Reduced for VM
    "net.core.netdev_budget" = 300;          # Default value
    "net.core.netdev_budget_usecs" = 2000;   # Default value

    # Polling optimizations
    "net.core.busy_read" = 50;
    "net.core.busy_poll" = 50;

    # Connection handling
    "net.core.somaxconn" = 262144;
    "net.core.optmem_max" = 134217728;

    # Queue discipline
    "net.core.default_qdisc" = "fq";

    # === TCP OPTIMIZATIONS ===
    # BBR congestion control
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Buffer sizing (VM appropriate values)
    "net.ipv4.tcp_rmem" = "4096 131072 134217728";     # More conservative
    "net.ipv4.tcp_wmem" = "4096 131072 134217728";     # More conservative
    "net.ipv4.tcp_mem" = "8388608 16777216 33554432";  # Reduced memory usage

    # Connection scaling
    "net.ipv4.tcp_max_syn_backlog" = 262144;
    "net.ipv4.tcp_max_tw_buckets" = 16000000;

    # Performance features
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_fack" = 1;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;

    # Aggressive timeouts for high-throughput
    "net.ipv4.tcp_fin_timeout" = 10;
    "net.ipv4.tcp_keepalive_time" = 120;
    "net.ipv4.tcp_keepalive_probes" = 3;
    "net.ipv4.tcp_keepalive_intvl" = 10;

    # Retransmission tuning
    "net.ipv4.tcp_retries1" = 2;
    "net.ipv4.tcp_retries2" = 5;
    "net.ipv4.tcp_synack_retries" = 2;
    "net.ipv4.tcp_syn_retries" = 2;

    # Additional optimizations
    "net.ipv4.tcp_adv_win_scale" = 2;
    "net.ipv4.tcp_moderate_rcvbuf" = 1;
    "net.ipv4.tcp_frto" = 2;
    "net.ipv4.tcp_low_latency" = 1;
    "net.ipv4.tcp_ecn" = 2;

    # Port range
    "net.ipv4.ip_local_port_range" = "1024 65535";

    # ARP table scaling for server workloads
    "net.ipv4.neigh.default.gc_thresh1" = 4096;
    "net.ipv4.neigh.default.gc_thresh2" = 8192;
    "net.ipv4.neigh.default.gc_thresh3" = 16384;

    # === SECURITY SETTINGS ===
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

    # === IPV6 OPTIMIZATIONS ===
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.default.autoconf" = 0;
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.default.accept_ra" = 0;

    # === VIRTUAL MEMORY OPTIMIZATIONS ===
    # Optimal for VM with moderate memory
    "vm.swappiness" = 10;          # Slightly higher for VM
    "vm.dirty_ratio" = 20;         # Conservative for VM
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 100; # Default value for VM

    # Memory mapping for applications
    "vm.max_map_count" = 262144;
    "vm.min_free_kbytes" = 65536;  # Reduced for VM

    # Hugepages - minimal allocation for VM
    "vm.nr_hugepages" = 256;       # 512MB instead of 16GB
    "vm.hugetlb_shm_group" = 0;

    # Memory management
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 50;    # More conservative for VM
    "vm.zone_reclaim_mode" = 0;
  };

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking = {
    hostName = "%HOST%"; # Define your hostname.
    useDHCP = false;
    interfaces."%INTERFACE%".useDHCP = true;
  };

  nix = {
    nixPath = [ "nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos" ];
    settings = {
      allowed-users = [ "${user}" ];
      trusted-users = [ "@admin" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    };

    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Enable sched-ext extensible scheduler framework
  environment.systemPackages = with pkgs; [
    # Add scx scheduler packages when available
    # Note: These may need to be built from source or custom overlay
  ];

  # Configure scx scheduler service
  systemd.services.scx-scheduler = {
    description = "SCX Scheduler Service";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${pkgs.writeShellScript "start-scx" ''
        # Set SCX scheduler to scx_lavd
        echo "scx_lavd" > /etc/default/scx
        # Start the scheduler (implementation depends on scx package)
        # This is a placeholder - actual implementation needed
      ''}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Create /etc/default/scx configuration
  environment.etc."default/scx".text = ''
    SCX_SCHEDULER="scx_lavd"
  '';

  # Manages keys and such
  programs = {
    gnupg.agent.enable = true;

    # Needed for anything GTK related
    dconf.enable = true;

    # My shell
    zsh.enable = true;
  };

  services = {
    displayManager.defaultSession = "none+bspwm";
    xserver = {
      enable = true;

      # Uncomment these for AMD or Nvidia GPU
      # videoDrivers = [ "amdgpu" ];
      # videoDrivers = [ "nvidia" ];

      # Uncomment this for Nvidia GPU
      # This helps fix tearing of windows for Nvidia cards
      # services.xserver.screenSection = ''
      #   Option       "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      #   Option       "AllowIndirectGLXProtocol" "off"
      #   Option       "TripleBuffer" "on"
      # '';

      # LightDM Display Manager
      displayManager.lightdm = {
        enable = true;
        greeters.slick.enable = true;
        background = ../../modules/nixos/config/login-wallpaper.png;
      };

      # Tiling window manager
      windowManager.bspwm = {
        enable = true;
      };

      xkb = {
        # Turn Caps Lock into Ctrl
        layout = "us";
        options = "ctrl:nocaps";
      };
    };

    # Better support for general peripherals
    libinput.enable = true;

    # Let's be able to SSH into this machine
    openssh.enable = true;

    # Sync state between machines
    # Sync state between machines
    syncthing = {
      enable = true;
      openDefaultPorts = true;
      dataDir = "/home/${user}/.local/share/syncthing";
      configDir = "/home/${user}/.config/syncthing";
      user = "${user}";
      group = "users";
      guiAddress = "127.0.0.1:8384";
      overrideFolders = true;
      overrideDevices = true;

      settings = {
        devices = {};
        options.globalAnnounceEnabled = false; # Only sync on LAN
      };
    };

    # Picom, my window compositor with fancy effects
    #
    # Notes on writing exclude rules:
    #
    #   class_g looks up index 1 in WM_CLASS value for an application
    #   class_i looks up index 0
    #
    #   To find the value for a specific application, use `xprop` at the
    #   terminal and then click on a window of the application in question
    #
    picom = {
      enable = true;
      settings = {
        animations = true;
        animation-stiffness = 300.0;
        animation-dampening = 35.0;
        animation-clamping = false;
        animation-mass = 1;
        animation-for-workspace-switch-in = "auto";
        animation-for-workspace-switch-out = "auto";
        animation-for-open-window = "slide-down";
        animation-for-menu-window = "none";
        animation-for-transient-window = "slide-down";
        corner-radius = 12;
        rounded-corners-exclude = [
          "class_i = 'polybar'"
          "class_g = 'i3lock'"
        ];
        round-borders = 3;
        round-borders-exclude = [];
        round-borders-rule = [];
        shadow = true;
        shadow-radius = 8;
        shadow-opacity = 0.4;
        shadow-offset-x = -8;
        shadow-offset-y = -8;
        fading = false;
        inactive-opacity = 0.8;
        frame-opacity = 0.7;
        inactive-opacity-override = false;
        active-opacity = 1.0;
        focus-exclude = [
        ];

        opacity-rule = [
          "100:class_g = 'i3lock'"
          "60:class_g = 'Dunst'"
          "100:class_g = 'Alacritty' && focused"
          "90:class_g = 'Alacritty' && !focused"
        ];

        blur-kern = "3x3box";
        blur = {
          method = "kernel";
          strength = 8;
          background = false;
          background-frame = false;
          background-fixed = false;
          kern = "3x3box";
        };

        shadow-exclude = [
          "class_g = 'Dunst'"
        ];

        blur-background-exclude = [
          "class_g = 'Dunst'"
        ];

        backend = "glx";
        vsync = false;
        mark-wmwin-focused = true;
        mark-ovredir-focused = true;
        detect-rounded-corners = true;
        detect-client-opacity = false;
        detect-transient = true;
        detect-client-leader = true;
        use-damage = true;
        log-level = "info";

        wintypes = {
          normal = { fade = true; shadow = false; };
          tooltip = { fade = true; shadow = false; opacity = 0.75; focus = true; full-shadow = false; };
          dock = { shadow = false; };
          dnd = { shadow = false; };
          popup_menu = { opacity = 1.0; };
          dropdown_menu = { opacity = 1.0; };
        };
      };
    };

    gvfs.enable = true; # Mount, trash, and other functionalities
    tumbler.enable = true; # Thumbnail support for images

    # Additional services can be configured here
  };

  # Additional systemd services can be configured here

  # Enable CUPS to print documents
  # services.printing.enable = true;
  # services.printing.drivers = [ pkgs.brlaser ]; # Brother printer driver

  # Enable sound
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Video support
  hardware = {
    graphics.enable = true;
    # nvidia.modesetting.enable = true;

    # Enable Xbox support
    # xone.enable = true;

    # Crypto wallet support
    ledger.enable = true;
  };


 # Add docker daemon
  virtualisation.docker.enable = true;
  virtualisation.docker.logDriver = "json-file";

  # It's me, it's you, it's everyone
  users.users = {
    ${user} = {
      isNormalUser = true;
      extraGroups = [
        "wheel" # Enable ‘sudo’ for the user.
        "docker"
      ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = keys;
    };

    root = {
      openssh.authorizedKeys.keys = keys;
    };
  };

  # Don't require password for users in `wheel` group for these commands
  security.sudo = {
    enable = true;
    extraRules = [{
      commands = [
       {
         command = "${pkgs.systemd}/bin/reboot";
         options = [ "NOPASSWD" ];
        }
      ];
      groups = [ "wheel" ];
    }];
  };

  fonts.packages = with pkgs; [
    dejavu_fonts
    jetbrains-mono
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];

  environment.systemPackages = with pkgs; [
    agenix.packages."${pkgs.system}".default # "x86_64-linux"
    gitAndTools.gitFull
    inetutils
  ];

  system.stateVersion = "21.05"; # Don't change this
}
