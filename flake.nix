# Streamlined NixOS Configuration - Zero Runtime Detection
{
  description = "Bulletproof NixOS Configuration with Profile-Based Architecture";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      system = "x86_64-linux";
      
      
      # All possible configurations - Hardware + Profile combinations
      configurations = {
        # VM Configurations - Perfect for testing and development
        "vm-minimal"    = { hardware = "vm-qemu";     profile = "minimal"; };
        "vm-workstation" = { hardware = "vm-qemu";     profile = "workstation"; };
        "vm-server"     = { hardware = "vm-qemu";     profile = "server"; };
        
        # Physical Machine Configurations
        "workstation"   = { hardware = "generic-uefi"; profile = "workstation"; };
        "server"        = { hardware = "generic-uefi"; profile = "server"; };
        "minimal"       = { hardware = "generic-uefi"; profile = "minimal"; };
      };
      
      # Function to build a system configuration
      mkSystem = name: { hardware, profile }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = inputs; # Removed 'user' variable
        modules = [
          # Layer 1: Base foundation (always included)
          ./profiles/base.nix
          
          # Layer 2: Hardware profile (explicit, no detection)
          ./hardware/${hardware}.nix
          
          # Layer 3: Use case profile (vm, workstation, server, minimal)
          ./profiles/${profile}.nix
          
          # Layer 4: VM-specific optimizations (only for VM configs)
          # Removed conditional for vm.nix, assume it's included in profile if needed
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
      };
      
      # Development shell for testing
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system};
          git
          nixos-rebuild
          nix-tree
        ];
        
        shellHook = ''
          echo "🚀 NixOS Config Development Shell"
          echo "Available configurations:"
          echo ${builtins.concatStringsSep "\n" (builtins.attrNames configurations)}
          echo ""
          echo "Test with: nix build .#nixosConfigurations.<config>.config.system.build.toplevel"
        '';
      };
      
      # Expose configurations for easy access
      packages.${system} = nixpkgs.lib.mapAttrs' (name: config: {
        name = "nixos-${name}";
        value = config.config.system.build.toplevel;
      }) self.nixosConfigurations;
    };
}