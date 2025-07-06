# Simplified NixOS Configuration
{
  description = "Simple NixOS Configuration - VM, Workstation, Server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... } @ inputs:
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
        
        # Build custom ISO with SSH access
        build-iso = {
          type = "app";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "build-iso" ''
            set -euo pipefail
            echo "🔨 Building custom NixOS ISO with SSH access..."
            echo "================================================"

            # Store the original working directory
            ORIGINAL_PWD="$(pwd)"

            echo "📦 Starting build process..."
            # Clean up any previous result symlink/directory
            rm -rf result

            # Build the ISO using nix-build
            nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=${./iso.nix}

            # Check if build succeeded and move the result
            if [ -f "result" ]; then # nix-build creates a direct symlink to the ISO file
                echo "✅ Build completed successfully!"
                echo ""
                echo "📍 ISO location:"
                # Ensure the target directory exists
                mkdir -p "$ORIGINAL_PWD/result/iso"
                # Copy the ISO file
                cp result "$ORIGINAL_PWD/result/iso/nixos-custom.iso" # Give it a generic name
                ls -la "$ORIGINAL_PWD/result/iso/nixos-custom.iso"
                echo ""
                echo "📋 To use the ISO:"
                echo "  - Copy to USB: sudo dd if=$ORIGINAL_PWD/result/iso/nixos-custom.iso of=/dev/sdX bs=4M status=progress"
                echo "  - Boot VM: qemu-system-x86_64 -enable-kvm -m 2048 -cdrom $ORIGINAL_PWD/result/iso/nixos-custom.iso"
                echo ""
                echo "🔑 SSH access:"
                echo "  - Root user has your SSH key pre-installed"
                echo "  - Default passwords: root='nixos', nixos='nixos'"
            else
                echo "❌ Build failed! No ISO file found."
                exit 1
            fi
          '');
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
          echo "  nix flake check               - Run declarative tests"
          echo ""
          echo "Testing: Use 'nix flake check' for integration tests"
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