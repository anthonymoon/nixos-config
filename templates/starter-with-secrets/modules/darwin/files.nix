{ user, config, pkgs, ... }:

let
  xdg_configHome = "${config.users.users.${user}.home}/.config";
  xdg_dataHome   = "${config.users.users.${user}.home}/.local/share";
  xdg_stateHome  = "${config.users.users.${user}.home}/.local/state"; in
{

  # Raycast script so that "Run Neovim" is available
  "${xdg_dataHome}/bin/nvim" = {
    executable = true;
    text = ''
      #!/bin/zsh
      #
      # Required parameters:
      # @raycast.schemaVersion 1
      # @raycast.title Run Neovim
      # @raycast.mode silent
      #
      # Optional parameters:
      # @raycast.packageName Neovim

      # Launch Neovim in Alacritty
      ${pkgs.alacritty}/bin/alacritty -e ${pkgs.neovim}/bin/nvim $@
    '';
  };
}
