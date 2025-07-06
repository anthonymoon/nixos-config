# Base Profile - Universal foundation for all systems
{ config, lib, pkgs, ... }:

{
  imports = [
    # Import user configuration if it exists (created during installation)
    # Note: pathExists with absolute paths not allowed in pure evaluation
  ];

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
      useDHCP = lib.mkForce true;
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
      # Create SSH directory structure
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
      createHome = true;
    };

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

    # Automatic SSH key generation service
    systemd.services.generate-user-ssh-key = {
      description = "Generate SSH key for user on first boot";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.myUser.username;
        Group = "users";
        ExecStart = pkgs.writeShellScript "generate-ssh-key" ''
          set -euo pipefail
          
          SSH_DIR="/home/${config.myUser.username}/.ssh"
          SSH_KEY="$SSH_DIR/id_ed25519"
          
          # Only generate if key doesn't exist
          if [[ ! -f "$SSH_KEY" ]]; then
            echo "Generating SSH key for ${config.myUser.username}..."
            mkdir -p "$SSH_DIR"
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "${config.myUser.username}@nixos"
            chmod 700 "$SSH_DIR"
            chmod 600 "$SSH_KEY"
            chmod 644 "$SSH_KEY.pub"
            echo "SSH key generated successfully"
          else
            echo "SSH key already exists, skipping generation"
          fi
        '';
      };
    };

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
      percentage = 50;
      # Higher priority makes the system prefer ZRAM swap.
      priority = 100;
    };


    # State version - updated to 25.05
    system.stateVersion = "25.05";
  };
}