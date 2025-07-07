
# /lib/default.nix
#
# This file exports a set of custom helper functions for this flake.
# By convention, a `default.nix` in a directory is automatically
# imported when the directory is referenced.
{
  /*
    mkSystem: A helper function to reduce boilerplate when defining NixOS systems.

    This function standardizes the creation of a `nixosSystem` by applying a
    common structure and set of special arguments.

    Arguments:
      - system: (String) The system architecture (e.g., "x86_64-linux").
      - inputs: (Attrs) The flake's top-level inputs, providing access to
                nixpkgs, home-manager, etc.
      - modules: (List) A list of NixOS modules to include in the system.
      - username: (String, Optional) The username for the user account.
      - hashedPassword: (String, Optional) The hashed password for the user.

    Returns:
      - (Attrs) A NixOS system configuration.
  */
  mkSystem = { system, inputs, modules, username ? null, hashedPassword ? null }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;

      # Pass down flake inputs and user data to all modules.
      specialArgs = inputs // {
        inherit username hashedPassword;
      };

      # Combine the provided modules with the base configuration.
      modules = [
        ../profiles/base.nix
      ] ++ modules;
    };
}
