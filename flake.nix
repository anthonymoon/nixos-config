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
          modules = [ ./modules/common.nix
            ./profiles/vm.nix
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            ./disko-config.nix
          ];
        };
        workstation = lib.mkSystem {
          inherit system inputs;
          modules = [ ./modules/common.nix
            ./profiles/workstation.nix
            self.nixosModules.display
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            ./disko-config.nix
          ];
        };
        server = lib.mkSystem {
          inherit system inputs;
          modules = [ ./modules/common.nix
            ./profiles/server.nix
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            ./disko-config.nix
          ];
        };
        iso = lib.mkSystem {
          inherit system inputs;
          modules = [ ./modules/common.nix
            ./profiles/iso.nix
            ./modules/display.nix
            home-manager.nixosModules.home-manager
          ];
        };
      };

      nixosModules.base = import ./profiles/base.nix;
      nixosModules.display = import ./modules/display.nix;

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

        build-vm-minimal = {
          type = "app";
          meta.description = "Build minimal VM disk image (headless, ~2GB)";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "build-vm-minimal" ''
            #!/usr/bin/env bash
            set -euo pipefail
            
            echo "🔨 Building minimal VM disk image..."
            echo "  Configuration: Headless server"
            echo "  Disk size: 4GB"
            echo "  Format: QCOW2"
            echo ""
            
            # Build the disk image
            if nix build .#vmImageMinimal --no-write-lock-file --extra-experimental-features 'nix-command flakes' --print-build-logs; then
              # Find the actual output file
              output_file=$(find result -name "*.qcow2" -o -name "*.img" -o -name "*.vdi" -o -name "*.vhd" | head -1)
              
              if [ -n "$output_file" ]; then
                echo ""
                echo "✅ Minimal VM image built successfully!"
                echo "📁 Output: $output_file"
                ls -lh "$output_file"
                echo ""
                echo "To run with QEMU:"
                echo "  qemu-system-x86_64 -enable-kvm -m 2048 -drive file=$output_file,if=virtio"
              else
                echo "❌ Build succeeded but no disk image found in result/"
                exit 1
              fi
            else
              echo "❌ Build failed"
              exit 1
            fi
          '');
        };

        build-vm-full = {
          type = "app";
          meta.description = "Build full VM disk image with desktop environment (~8GB)";
          program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "build-vm-full" ''
            #!/usr/bin/env bash
            set -euo pipefail
            
            echo "🔨 Building full VM disk image with desktop..."
            echo "  Configuration: Workstation with dwl/greetd"
            echo "  Disk size: 20GB"
            echo "  Format: QCOW2"
            echo ""
            
            # Build the disk image
            if nix build .#vmImageFull --no-write-lock-file --extra-experimental-features 'nix-command flakes' --print-build-logs; then
              # Find the actual output file
              output_file=$(find result -name "*.qcow2" -o -name "*.img" -o -name "*.vdi" -o -name "*.vhd" | head -1)
              
              if [ -n "$output_file" ]; then
                echo ""
                echo "✅ Full VM image built successfully!"
                echo "📁 Output: $output_file"
                ls -lh "$output_file"
                echo ""
                echo "To run with QEMU:"
                echo "  qemu-system-x86_64 -enable-kvm -m 4096 -drive file=$output_file,if=virtio -vga qxl"
              else
                echo "❌ Build succeeded but no disk image found in result/"
                exit 1
              fi
            else
              echo "❌ Build failed"
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
          echo "  nix run .#build-vm-minimal    - Build minimal VM disk image (~2GB)"
          echo "  nix run .#build-vm-full       - Build full VM disk image with desktop (~8GB)"
          echo ""
        '';
      };

      # Disko configuration for disk partitioning
      diskoConfigurations.default = import ./disko-config.nix;

      # Expose configurations for easy access
      packages.${system} = (nixpkgs.lib.mapAttrs' (name: config: {
        name = "nixos-${name}";
        value = config.config.system.build.toplevel;
      }) self.nixosConfigurations) // {
        iso = self.nixosConfigurations.iso.config.system.build.isoImage;
        
        # VM disk images
        vmImageMinimal = let
          evalConfig = import (nixpkgs + "/nixos/lib/eval-config.nix");
          vmConfig = evalConfig {
            inherit system;
            modules = [ 
              ./vm-images/minimal.nix
              home-manager.nixosModules.home-manager
            ];
          };
        in import (nixpkgs + "/nixos/lib/make-disk-image.nix") {
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          config = vmConfig.config;
          diskSize = "4096"; # 4GB for minimal
          format = "qcow2";
          partitionTableType = "hybrid";
          installBootLoader = true;
          touchEFIVars = true;
          copyChannel = false;
          memSize = 2048;
        };
        
        vmImageFull = let
          evalConfig = import (nixpkgs + "/nixos/lib/eval-config.nix");
          vmConfig = evalConfig {
            inherit system;
            modules = [ 
              ./vm-images/full.nix
              home-manager.nixosModules.home-manager
            ];
          };
        in import (nixpkgs + "/nixos/lib/make-disk-image.nix") {
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;
          config = vmConfig.config;
          diskSize = "20480"; # 20GB for full desktop
          format = "qcow2";
          partitionTableType = "hybrid";
          installBootLoader = true;
          touchEFIVars = true;
          copyChannel = false;
          memSize = 4096;
        };
      };
    };
}