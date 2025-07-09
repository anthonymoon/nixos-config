---
description: "Builds a specified NixOS profile locally after verifying the OS."
---

## Your Task

You are about to test a NixOS profile. It is critical that you first verify you are running on NixOS and then build the profile locally before attempting any deployment.

**Instructions:**

1.  **Verify Operating System:**
    *   Run the following command to check the OS identity:
        ```bash
        grep '^ID=' /etc/os-release
        ```
    *   Analyze the output. If it is not `ID=nixos`, abort the test and inform the user.

2.  **Build Profile (if OS is NixOS):**
    *   You have been provided a profile name as an argument.
    *   Execute the following command, replacing `<profile>` with the provided argument:
        ```bash
        nix build .#$ARGUMENTS
        ```
    *   Analyze the output. If the build fails, report the error. If it succeeds, confirm that the profile is ready for the next step.