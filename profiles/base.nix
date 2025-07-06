# Base Profile - Universal foundation for all systems
{ config, lib, pkgs, ... }:

{
  options.myUser.username = lib.mkOption {
    type = lib.types.str;
    default = "amoon";
    description = "Primary user for the system.";
  };

  config = {
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
      useDHCP = lib.mkDefault true;
    };

    # Locale and timezone
    time.timeZone = lib.mkDefault "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    # Essential user setup
    users.users.${config.myUser.username} = {
      isNormalUser = true;
      description = "Primary User";
      extraGroups = [ "wheel" "networkmanager" ];
      shell = pkgs.zsh;
    };

    # Security defaults
    security.sudo.wheelNeedsPassword = false;

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
    services = {
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = true;
          PermitRootLogin = "no";
        };
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

    # Secrets management directory (configured by agenix module)
    # age.secrets = {
    #   # Example secret configuration
    #   # user-password.file = ../secrets/user-password.age;
    # };

    # State version - updated to 25.05
    system.stateVersion = "25.05";
  };
}