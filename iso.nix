{ config, pkgs, lib, modulesPath, options, ... }:
let
  extraPackages = []; # Define extraPackages locally if not passed as an argument
in
{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    <nixpkgs/nixos/modules/installer/cd-dvd/iso-image.nix> # Import iso-image module
  ];

  isoImage.size = "2G"; # Increase ISO image size

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