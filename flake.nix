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
      nixosConfigurations = {
        vm = lib.mkSystem {
          inherit system inputs;
          modules = [
            ./profiles/vm.nix
            home-manager.nixosModules.home-manager
          ];
        };
        workstation = lib.mkSystem {
          inherit system inputs;
          modules = [
            ./profiles/workstation.nix
            home-manager.nixosModules.home-manager
          ];
        };
        server = lib.mkSystem {
          inherit system inputs;
          modules = [
            ./profiles/server.nix
            home-manager.nixosModules.home-manager
          ];
        };
        iso = lib.mkSystem {
          inherit system inputs;
          modules = [
            ./profiles/iso.nix
            home-manager.nixosModules.home-manager
          ];
        };
      };

      # Apps for building and installing
      apps.${system} = {
        install = {
          type = "app";
          meta.description = "Interactive NixOS installer script with flake-based configuration";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "install" ''
            export NIXOS_CONFIG_FLAKE="github:anthonymoon/nixos-config"
            exec ${./install/install.sh} "$@"
          '');
        };

        disko = {
          type = "app";
          meta.description = "Declarative disk partitioning and formatting tool";
          program = "${disko.packages.${system}.default}/bin/disko";
        };

        build-iso = {
          type = "app";
          meta.description = "Build custom NixOS ISO with SSH access and installation tools";
          program = "${self.nixosConfigurations.iso.config.system.build.isoImage}/bin/nixos-iso";
        };
      };

      # Development shell for testing
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          git
          nixos-rebuild
          nix-tree
          disko.packages.${system}.default
        ];

        shellHook = ''
          echo "🚀 NixOS Config Development Shell"
          echo "Available configurations: vm, workstation, server"
          echo ""
          echo "Commands:"
          echo "  nix run .#install <config>     - Install NixOS configuration"
          echo "  nix run .#build-iso           - Build custom ISO with SSH access"
          echo ""
        '';
      };

      # Disko configuration for disk partitioning
      diskoConfigurations.default = import ./disko-config.nix;

      # Expose configurations for easy access
      packages.${system} = nixpkgs.lib.mapAttrs' (name: config: {
        name = "nixos-${name}";
        value = config.config.system.build.toplevel;
      }) self.nixosConfigurations;
    };
}