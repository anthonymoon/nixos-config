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
  # Import user configuration if it exists
  imports = lib.optional (builtins.pathExists /etc/nixos/user-config.nix) /etc/nixos/user-config.nix;

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
        kernelParams = [ "quiet" "loglevel=3" ];
      };

      # Networking - basic and reliable
      networking = {
        networkmanager.enable = true;
        firewall.enable = true;
        useDHCP = lib.mkForce true;
      };

      # Locale and timezone
      time.timeZone = lib.mkDefault "UTC";
      i18n.defaultLocale = "en_US.UTF-8";

      # Security defaults
      security.sudo.wheelNeedsPassword = true;

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

      # Essential services
      services.openssh = {
        enable = true;
        # Password authentication is enabled by default here for initial setup.
        # This is overridden to 'false' in the security module for hardened systems.
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      # Shell configuration
      programs.zsh.enable = true;

    # Nix configuration
    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
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
    }
  ];
}