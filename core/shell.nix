{ system, nixpkgs, inputs }:
nixpkgs.legacyPackages.${system}.mkShell {
  buildInputs = with nixpkgs.legacyPackages.${system}; [
    git
    nixos-rebuild
    nix-tree
    inputs.disko.packages.${system}.default
  ];

  shellHook = ''
    echo "🚀 NixOS Config Development Shell"
    echo "Available configurations: vm, workstation, server"
    echo ""
    echo "Commands:"
    echo "  nix run .#install <config>     - Install NixOS configuration"
    echo "  nix run .#build-iso           - Build custom ISO with SSH access"
    echo ""
  '';
}
