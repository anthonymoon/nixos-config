{ lib, system, inputs }:
lib.mkSystem {
  inherit system inputs;
  modules = [
    ../../modules/common.nix
    ../../profiles/iso.nix
    inputs.home-manager.nixosModules.home-manager
  ];
}
