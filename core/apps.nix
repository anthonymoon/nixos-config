{ self, system, nixpkgs, inputs }:
{
  install = {
    type = "app";
    meta.description = "Interactive NixOS installer script with flake-based configuration";
    program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "install" ''
      export NIXOS_CONFIG_FLAKE="github:anthonymoon/nixos-config"
      exec ${../../install/install.sh} "$@"
    '');
  };

  disko = {
    type = "app";
    meta.description = "Declarative disk partitioning and formatting tool";
    program = "${inputs.disko.packages.${system}.default}/bin/disko";
  };

  build-iso = {
    type = "app";
    meta.description = "Build custom NixOS ISO with SSH access and installation tools";
    program = "${self.nixosConfigurations.iso.config.system.build.isoImage}/bin/nixos-iso";
  };
}
