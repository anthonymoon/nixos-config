### Agentic Rules for `nixos-config`

These rules are mandatory for all operations within this repository.

1.  **System Configuration:**
    *   **Rolling Release:** The system is a rolling release based on `nixos-unstable`. Do not use lock files (`flake.lock`). All Nix commands must use `--no-write-lock-file` and enable all experimental features (`--extra-experimental-features 'nix-command flakes'`).
    *   **Unattended Installation:** All installation and deployment processes must be non-interactive. Automatically confirm disk partitioning and any other prompts.
    *   **Firewall Disabled:** The firewall must be disabled on all profiles. `networking.firewall.enable` must be `false`.

2.  **User & SSH Management (Universal):**
    *   **Standard Users:** Ensure the users `root`, `nixos`, and `amoon` exist on all profiles.
    *   **Universal SSH Key:** The following public SSH key must be added to the `authorized-keys` for all three standard users (`root`, `nixos`, `amoon`):
        ```
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us
        ```
    *   **SSH Service:** The OpenSSH daemon (`services.openssh.enable`) must be enabled on all profiles, allowing passwordless root login (`permitRootLogin = "prohibit-password";`).

3.  **Development Workflow:**
    *   **Nix DSL First:** Always prefer implementing logic directly in the Nix language over shelling out to scripts.
    *   **Local Verification:** All changes must be validated with a local build (`nix build .#<profile>`) before being committed.
