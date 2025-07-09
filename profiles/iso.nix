{ config, pkgs, lib, modulesPath, nixpkgs, ... }:
let
  extraPackages = []; # Define extraPackages locally if not passed as an argument
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
    ../modules/development.nix
    
  ];
  
  # Enable development module
  modules.development.enable = true;

  # ISO configuration
  isoImage.isoName = "nixos-custom-${pkgs.stdenv.hostPlatform.system}.iso";
  isoImage.squashfsCompression = "gzip -Xcompression-level 1"; # Faster compression
  
  # Enable SSH in the boot process
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  
  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkForce "yes";
      PasswordAuthentication = true;
    };
  };
  
  # Set default passwords for initial access
  users.users.root = {
    initialPassword = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
    ];
  };
  users.users.nixos = {
    initialPassword = lib.mkForce "nixos";
    initialHashedPassword = lib.mkForce null;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
    ];
  };
  
  # Network configuration for ISO
  networking = {
    # Disable wireless as it conflicts with NetworkManager
    wireless.enable = lib.mkForce false;
    # Enable NetworkManager for easier network configuration
    networkmanager.enable = true;
    # Let NetworkManager handle DHCP
    useDHCP = lib.mkForce false;
    useNetworkd = false;
  };
  
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
    # Additional virtualization tools for ISO
    qemu_full
    libvirt
    virt-manager
    virt-viewer
    spice-vdagent
  ] ++ extraPackages;
  
  # Load KVM modules
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
  
  # Enable QEMU guest agent for when ISO runs as VM
  services.qemuGuest.enable = true;

  boot.kernel.sysctl."vm.overcommit_memory" = lib.mkForce "1";
  
  # Set GRUB boot timeout for faster boot
  boot.loader.timeout = lib.mkForce 3;
}