{ lib, system, inputs }:
lib.mkSystem {
  inherit system inputs;
  modules = [
    ../../modules/common.nix
    ../../profiles/vm.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.disko.nixosModules.disko
    ../../disko-config.nix
  ];
}
