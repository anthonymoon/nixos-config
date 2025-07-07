# Home Manager configuration for the primary user
{
  config,
  pkgs,
  lib,
  username,
  ... # Accept all specialArgs
}:

{
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "25.05"; # Updated to latest version

  # The home.packages option allows you to install packages into your
  # user profile.
  home.packages = with pkgs; [
    # Add your user-specific packages here
    htop
    btop
    fastfetch
  ];

  # Manage environment variables
  home.sessionVariables = {
    EDITOR = "vim";
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
