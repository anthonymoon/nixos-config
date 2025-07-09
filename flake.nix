# Simplified NixOS Configuration
{
  description = "Simple NixOS Configuration - VM, Workstation, Server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      # Import our custom library
      lib = import ./lib;
    in
    {
      # Expose the custom lib for external use
      inherit lib;

      # Define NixOS configurations using the helper function
      nixosConfigurations = import ./core/nixos-configurations { inherit lib system inputs; };

      # Apps for building and installing
      apps.${system} = import ./core/apps.nix { inherit self system nixpkgs inputs; };

      # Development shell for testing
      devShells.${system}.default = import ./core/shell.nix { inherit system nixpkgs inputs; };

      # Disko configuration for disk partitioning
      diskoConfigurations.default = import ./disko-config.nix;

      # Expose configurations for easy access
      packages.${system} = nixpkgs.lib.mapAttrs' (name: config: {
        name = "nixos-${name}";
        value = config.config.system.build.toplevel;
      }) self.nixosConfigurations;
    };
}
