# Simplified NixOS Configuration
{
  description = "Simple NixOS Configuration - VM, Workstation, Server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix, ... } @ inputs:
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
          # agenix.nixosModules.default
        ];
      };
      
    in {
      # Generate all system configurations
      nixosConfigurations = nixpkgs.lib.mapAttrs mkSystem configurations;
      
      # Single installer for all configurations
      apps.${system} = {
        install = {
          type = "app";
          program = "${./install/install.sh}";
        };
        install-vm = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "install-vm" ''
            ${./install/install.sh} vm
          '');
        };
        install-workstation = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "install-workstation" ''
            ${./install/install.sh} workstation
          '');
        };
        install-server = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "install-server" ''
            ${./install/install.sh} server
          '');
        };
        post-install = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "post-install-wrapper" ''
            exec ${./scripts/post-install.sh} "$@"
          '');
        };
      };
      
      # Development shell for testing
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          git
          nixos-rebuild
          nix-tree
          # agenix.packages.${system}.default  # Disabled - uncomment when secrets are needed
        ];
        
        shellHook = ''
          echo "🚀 NixOS Config Development Shell"
          echo "Available configurations: vm, workstation, server"
          echo ""
          echo "Test with: nix build .#nixosConfigurations.<config>.config.system.build.toplevel"
          echo "Install with: sudo nix run .#install <config>"
        '';
      };
      
      # Expose configurations for easy access
      packages.${system} = nixpkgs.lib.mapAttrs' (name: _: {
        name = "nixos-${name}";
        value = (mkSystem name configurations.${name}).config.system.build.toplevel;
      }) configurations;
    };
}