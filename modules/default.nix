# modules/default.nix
# 
# This file provides a unified interface to all modules in this directory.
# It allows importing the entire modules directory as a single attribute set.
{
  common = import ./common.nix;
  development = import ./development.nix;
  display = import ./display.nix;
  gaming = import ./gaming.nix;
  home = import ./home.nix;
  kernel = import ./kernel.nix;
  media-server = import ./media-server.nix;
  security = import ./security.nix;
}