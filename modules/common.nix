# Common configuration for all profiles
{
  config,
  pkgs,
  lib,
  ... # This represents the function arguments that are passed to a NixOS module.
}:
{
  # ---
  # Universal User and SSH Configuration
  # ---

  # Enable OpenSSH daemon
  services.openssh = {
    enable = true;
    settings = {
      # Allow root login with password
      PermitRootLogin = "yes";
      # Enable password authentication
      PasswordAuthentication = true;
    };
  };

  # Define standard users
  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    nixos = {
      isNormalUser = true;
      extraGroups = [ "wheel" ]; # For sudo access
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    amoon = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
  };

  # Disable the firewall
  networking.firewall.enable = false;

  # Enable all experimental Nix features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
