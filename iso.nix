{ config, pkgs, lib, modulesPath, options, ... }:
let
  extraPackages = []; # Define extraPackages locally if not passed as an argument
in
{
{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
  ];
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