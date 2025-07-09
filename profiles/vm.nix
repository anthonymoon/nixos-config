# VM Profile - Virtual machine optimized
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../modules/display.nix
  ];

  # Filesystem configuration handled by Disko
  # No swap devices - using ZRAM from base profile
  # Hardware configuration handled by universal kernel module

  # VM hardware settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  
  # VM-specific optimizations (override kernel module defaults)
  powerManagement.cpuFreqGovernor = lib.mkForce "ondemand";
  hardware.cpu.intel.updateMicrocode = false; # Not needed in VMs
  hardware.cpu.amd.updateMicrocode = false; # Not needed in VMs
  
  # VM optimizations
  services = {
    spice-vdagentd.enable = true;
    services.qemuGuest.enable = true;

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Firewall disabled
  networking.firewall.enable = false;
  };

  # VM-specific packages
  environment.systemPackages = with pkgs; [
    spice-vdagent
    qemu-utils
  ];

  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    nixos = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
    amoon = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
      ];
    };
  };
}