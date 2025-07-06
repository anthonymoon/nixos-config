{
  description = "Custom NixOS installation ISO with SSH access";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = self.nixosConfigurations.customIso.config.system.build.isoImage;
    
    nixosConfigurations = {
      customIso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ pkgs, modulesPath, ... }: {
            imports = [ 
              (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
              (modulesPath + "/installer/cd-dvd/channel.nix")
            ];
            
            # Enable SSH in the boot process
            systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
            
            # To add SSH keys to the ISO, uncomment and replace with your public keys:
            # users.users.root.openssh.authorizedKeys.keys = [
            #   "ssh-ed25519 YOUR_ROOT_SSH_PUBLIC_KEY"
            # ];
            # users.users.nixos = {
            #   openssh.authorizedKeys.keys = [
            #     "ssh-ed25519 YOUR_NIXOS_SSH_PUBLIC_KEY"
            #   ];
            # };
            
            # Essential packages for installation
            environment.systemPackages = with pkgs; [
              vim
              git
              curl
              wget
              htop
              tmux
              rsync
            ];
            
            # Enable experimental features by default
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            
            # Enable NetworkManager for easier network configuration
            networking.networkmanager.enable = true;
            
            # Faster compression for quicker builds
            isoImage.squashfsCompression = "gzip -Xcompression-level 1";
            
            # Custom ISO naming
            isoImage.isoName = "nixos-ssh-${pkgs.stdenv.hostPlatform.system}.iso";
            
            # Enable password authentication for initial setup if needed
            services.openssh = {
              enable = true;
              settings = {
                PermitRootLogin = "yes";
                PasswordAuthentication = true;
              };
            };
            
            # Set a default password for root (can be changed after boot)
            users.users.root.initialPassword = "nixos";
            users.users.nixos.initialPassword = "nixos";
            
            # Ensure the ISO boots with networking enabled
            networking.useDHCP = true;
            networking.useNetworkd = false;  # Use dhcpcd instead
            networking.dhcpcd.enable = true;
            networking.dhcpcd.wait = "background";  # Don't block boot waiting for DHCP
            
            # Include our nixos-config flake in the ISO for easy installation
            environment.etc."nixos-config-flake-uri".text = "github:anthonymoon/nixos-config";
          })
        ];
      };
    };
  };
}