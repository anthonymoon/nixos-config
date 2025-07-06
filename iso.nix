{ config, pkgs, lib, modulesPath, options, ... }:
let
  extraPackages = []; # Define extraPackages locally if not passed as an argument
in
{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];

  # ISO configuration
  isoImage.isoName = "nixos-custom-${pkgs.stdenv.hostPlatform.system}.iso";
  isoImage.squashfsCompression = "gzip -Xcompression-level 1"; # Faster compression
  
  # Enable SSH in the boot process
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  
  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };
  
  # Set default passwords for initial access
  users.users.root.initialPassword = "nixos";
  users.users.nixos.initialPassword = "nixos";
  
  # Enable NetworkManager for easier network configuration
  networking.networkmanager.enable = true;
  
  # Ensure DHCP is enabled
  networking.useDHCP = true;
  networking.useNetworkd = false;
  networking.dhcpcd.enable = true;
  networking.dhcpcd.wait = "background";
  
  # Enable experimental features by default
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Include our nixos-config flake URI for easy installation
  environment.etc."nixos-config-flake-uri".text = "github:anthonymoon/nixos-config";

  environment.systemPackages = with pkgs; [
    neovim
    openssh # For scp
    htop
    iotop
    nmap
    netcat
    tcpdump
    tmux
    git
    curl
    wget
    tree
    unzip
    which
    ddrescue # More robust than dd for recovery
    rsync
  ] ++ extraPackages;
}