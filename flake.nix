{
  description = "General Purpose Configuration for macOS and NixOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager.url = "github:nix-community/home-manager";
    agenix.url = "github:ryantm/agenix";
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs = { 
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@github.com/dustinlyons/nix-secrets.git";
      flake = false;
    };
  };
  outputs = { self, claude-desktop, home-manager, plasma-manager, nixpkgs, flake-utils, disko, agenix, secrets } @inputs:
    let
      user = "amoon";
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs linuxSystems f;
      devShell = system: let pkgs = nixpkgs.legacyPackages.${system}; in {
        default = with pkgs; mkShell {
          nativeBuildInputs = with pkgs; [ bashInteractive git age age-plugin-yubikey ];
          shellHook = with pkgs; ''
            export EDITOR=vim
          '';
        };
      };
      mkApp = scriptName: system: {
        type = "app";
        program = "${(nixpkgs.legacyPackages.${system}.writeScriptBin scriptName ''
          #!/usr/bin/env bash
          PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
          echo "Running ${scriptName} for ${system}"
          exec ${self}/apps/${system}/${scriptName}
        '')}/bin/${scriptName}";
      };
      mkLinuxApps = system: {
        "apply" = mkApp "apply" system;
        "build-switch" = mkApp "build-switch" system;
        "copy-keys" = mkApp "copy-keys" system;
        "create-keys" = mkApp "create-keys" system;
        "check-keys" = mkApp "check-keys" system;
        "install" = mkApp "install" system;
        "install-with-secrets" = mkApp "install-with-secrets" system;
      };
    in
    {
      templates = {
        starter = {
          path = ./templates/starter;
          description = "Starter configuration";
        };
        starter-with-secrets = {
          path = ./templates/starter-with-secrets;
          description = "Starter configuration with secrets";
        };
      };
      
      # Add VM integration tests as a check
      checks = forAllSystems (system: {
        vm-test = import ./tests/vm-integration.nix {
          inherit (nixpkgs.legacyPackages.${system}) pkgs lib;
        };
      });
      
      devShells = forAllSystems devShell;
      apps = nixpkgs.lib.genAttrs linuxSystems mkLinuxApps;
      nixosConfigurations = nixpkgs.lib.genAttrs linuxSystems (system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = inputs // { inherit user; };
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager {
              home-manager = {
                sharedModules = [ plasma-manager.homeManagerModules.plasma-manager ]; 
                useGlobalPkgs = true;
                useUserPackages = true;
                users.${user} = { config, pkgs, lib, ... }:
                  import ./modules/nixos/home-manager.nix { inherit config pkgs lib inputs; };
              };
            }
            ./hosts/nixos
          ];
        }
      );
    };
}
