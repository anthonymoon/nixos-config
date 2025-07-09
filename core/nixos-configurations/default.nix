{ lib, system, inputs }:
{
  vm = import ./vm.nix { inherit lib system inputs; };
  workstation = import ./workstation.nix { inherit lib system inputs; };
  server = import ./server.nix { inherit lib system inputs; };
  iso = import ./iso.nix { inherit lib system inputs; };
}
