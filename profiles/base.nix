# Base Profile - Universal foundation for all systems
{
  config,
  lib,
  pkgs,
  username ? null,
  hashedPassword ? null,
  ... # Allow other specialArgs to be passed
}:

{
  # No user configuration import needed - users defined here

  # This configuration is applied only when a username is provided.
  config = lib.mkMerge [
    # Always include base configuration
    {
      # Boot configuration - works everywhere
      boot = {
        loader = {
          systemd-boot = {
            enable = true;
            configurationLimit = 10;
          };
          efi.canTouchEfiVariables = true;
        };
        
        # Essential kernel modules
        initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
        kernelModules = [ ];
        
        # Safe kernel parameters
        kernelParams = [ 
          "quiet" 
          "loglevel=3"
          # Enable nested virtualization
          "kvm_intel.nested=1"
          "kvm_amd.nested=1"
          "kvm.ignore_msrs=1"
          "kvm.report_ignored_msrs=0"
        ];
      };

      # Networking - basic and reliable
      networking = {
        networkmanager.enable = true;
        # firewall disabled in common.nix
        useDHCP = lib.mkForce true;
      };

      # Locale and timezone
      time.timeZone = lib.mkDefault "UTC";
      i18n.defaultLocale = "en_US.UTF-8";

      # Security defaults
      # sudo configuration moved to users section

      # Essential packages - minimal but functional
      environment.systemPackages = with pkgs; [
        vim
        git
        curl
        wget
        htop
        tree
        unzip
        which
      ];

      # SSH configuration handled in common.nix

      # Shell configuration
      programs.zsh.enable = true;

    # Nix configuration
    nix = {
      settings = {
        # experimental features handled in common.nix
        auto-optimise-store = true;
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;

    # ZRAM swap configuration - better than traditional swap
    zramSwap = {
      enable = true;
      # Use 50% of physical RAM for the ZRAM device size.
      memoryPercent = 50;
      # Higher priority makes the system prefer ZRAM swap.
      priority = 100;
    };

    # State version - updated to 25.05
    system.stateVersion = "25.05";
    
    # Users handled in common.nix
    # Additional groups for specific users
    users.users = {
      nixos.extraGroups = [ "networkmanager" ];
      amoon.extraGroups = [ "networkmanager" "docker" "libvirtd" "kvm" ];
    };
    
    # Allow wheel users to use sudo without password
    security.sudo.wheelNeedsPassword = false;
    }
  ];
}