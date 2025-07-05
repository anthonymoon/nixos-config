# Minimal Profile - Bare essentials only
{ config, lib, pkgs, ... }:

{
  # Minimal package set
  environment.systemPackages = with pkgs; [
    # Base profile already includes: vim git curl wget htop tree unzip which
    # Add nothing extra for minimal
  ];

  # Minimal services - SSH only
  services = {
    # Base profile already enables openssh
    # Disable anything extra
  };

  # Performance optimizations for minimal systems
  powerManagement.enable = lib.mkDefault false;
  
  # Disable documentation to save space
  documentation.enable = false;
  documentation.nixos.enable = false;
}