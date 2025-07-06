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
        
        # Agent-based testing framework
        test-agent = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "test-agent" ''
            export PATH="${nixpkgs.legacyPackages.${system}.lib.makeBinPath [
              nixpkgs.legacyPackages.${system}.libvirt
              nixpkgs.legacyPackages.${system}.qemu
              nixpkgs.legacyPackages.${system}.python3
              nixpkgs.legacyPackages.${system}.openssh
              nixpkgs.legacyPackages.${system}.rsync
              nixpkgs.legacyPackages.${system}.wget
            ]}:$PATH"
            export NIXOS_CONFIG_FLAKE="${flake_uri:-github:anthonymoon/nixos-config}"
            cd ${./.}
            exec ./testing/test-orchestrator.sh "$@"
          '');
        };
        
        # VM management utility
        vm-manager = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "vm-manager" ''
            export PATH="${nixpkgs.legacyPackages.${system}.lib.makeBinPath [
              nixpkgs.legacyPackages.${system}.libvirt
              nixpkgs.legacyPackages.${system}.qemu
              nixpkgs.legacyPackages.${system}.wget
            ]}:$PATH"
            cd ${./.}
            exec ./testing/vm-manager.sh "$@"
          '');
        };
        
        # Build custom ISO with SSH access
        build-iso = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "build-iso" ''
            cd ${./.}/iso
            echo "Building custom NixOS ISO with SSH access..."
            nix build --no-link --print-out-paths
            echo "ISO built successfully!"
            echo "Find it in the result/iso/ directory"
          '');
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
          # Agent testing framework dependencies
          libvirt
          qemu
          python3
          openssh
          rsync
          wget
        ];
        
        shellHook = ''
          echo "🚀 NixOS Config Development Shell"
          echo "Available configurations: vm, workstation, server"
          echo ""
          echo "Commands:"
          echo "  nix run .#test-agent setup     - Setup agent testing environment"
          echo "  nix run .#test-agent test      - Run agent-based installation tests"
          echo "  nix run .#vm-manager setup     - Setup VM infrastructure only"
          echo "  nix run .#install <config>     - Install NixOS configuration"
          echo "  nix flake check               - Run declarative tests"
          echo ""
          echo "🤖 Agent-based testing with real-time monitoring and self-healing"
        '';
      };
      
# Disko configuration for disk partitioning
      diskoConfigurations.default = ./disko-config.nix;
      
      # Integration tests using nixos-tests framework
      checks.${system} = 
        let
          pkgs = nixpkgs.legacyPackages.${system};
          testSuite = import ./tests.nix { 
            inherit pkgs; 
            lib = nixpkgs.lib;
          };
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