# Simplified NixOS Configuration
{
  description = "Simple NixOS Configuration - VM, Workstation, Server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix, disko, ... } @ inputs:
    let
      system = "x86_64-linux";
      
      # Simple configurations - just 3 types
      configurations = {
        "vm"          = ./profiles/vm.nix;
        "workstation" = ./profiles/workstation.nix;
        "server"      = ./profiles/server.nix;
      };
      
      # Function to build a system configuration
      mkSystem = name: config: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = inputs;
        modules = [
          ./profiles/base.nix
          config
          ./disko-config.nix
          agenix.nixosModules.default
          disko.nixosModules.default
        ];
      };
      
    in {
      # Generate all system configurations
      nixosConfigurations = nixpkgs.lib.mapAttrs mkSystem configurations;
      
      # Universal installer - user can select profile interactively or via arguments
      apps.${system} = {
        install = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "install" ''
            export NIXOS_CONFIG_FLAKE="github:anthonymoon/nixos-config"
            exec ${./install/install.sh} "$@"
          '');
        };
        
        # Disko app for disk partitioning
        disko = {
          type = "app";
          program = "${disko.packages.${system}.default}/bin/disko";
        };
      };
      
      # Development shell for testing
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          git
          nixos-rebuild
          nix-tree
          agenix.packages.${system}.default
          disko.packages.${system}.default
        ];
        
        shellHook = ''
          echo "🚀 NixOS Config Development Shell"
          echo "Available configurations: vm, workstation, server"
          echo ""
          echo "Test with: nix build .#nixosConfigurations.<config>.config.system.build.toplevel"
          echo "Install with: sudo nix run .#install <config>"
        '';
      };
      
# Disko configuration for disk partitioning
      diskoConfigurations.default = ./disko-config.nix;
      
      # Integration tests using nixos-tests framework
      checks.${system} = 
        let
          testSuite = import ./tests.nix { inherit pkgs lib; };
        in {
          vm-test = testSuite.vm-test;
          workstation-test = testSuite.workstation-test;
          server-test = testSuite.server-test;
          network-test = testSuite.network-test;
        };

      # Expose configurations for easy access
      packages.${system} = nixpkgs.lib.mapAttrs' (name: _: {
        name = "nixos-${name}";
        value = (mkSystem name configurations.${name}).config.system.build.toplevel;
      }) configurations;
    };
}