#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash coreutils gnugrep gnused gawk findutils
# Bulletproof NixOS Installer - Zero-Failure Architecture
#
# This script is designed to be run from the NixOS installer environment.
# It automates the entire installation process, from disk partitioning
# to NixOS installation, using a declarative flake-based approach.
#
# shellcheck disable=SC2126  # wc -l is intentional for disk counting

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
# Use the same flake URI that was used to run this installer
# This ensures consistency between installer and installation target
FLAKE_URI="${NIXOS_CONFIG_FLAKE:-github:anthonymoon/nixos-config}"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running in NixOS installer
check_installer() {
    if [[ ! -e /etc/NIXOS ]]; then
        error "Not running in NixOS installer environment"
    fi
    log "Running in NixOS installer environment ✓"
}

# Select configuration
select_config() {
    if [[ $# -gt 0 ]]; then
        echo "$1"
        return
    fi

    echo -e "${BLUE}Available NixOS Configurations:${NC}"
    echo "────────────────────────────────────────"
    echo "vm          - Virtual machine optimized"
    echo "workstation - Desktop with GUI and development tools"
    echo "server      - Headless server with security hardening"
    echo "────────────────────────────────────────"
    
    while true; do
        read -r -p "Select a configuration [vm/workstation/server]: " choice
        case "$choice" in
            vm|workstation|server)
                echo "$choice"
                return
                ;;
            *)
                warn "Invalid choice. Please select: vm, workstation, or server"
                ;;
        esac
    done
}

# Detect available disks for user selection
detect_disk() {
    log "Available disks (excluding CD-ROM/DVD):"
    # Show only real disks, not CD-ROM or loop devices
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "disk|nvme" | grep -v -E "rom|loop" || true
    
    # Check if we have any valid disks
    local disk_count
    disk_count=$(lsblk -d -o TYPE | grep -E "disk|nvme" | grep -v -E "rom|loop" | wc -l || echo "0")
    if [[ "$disk_count" -eq 0 ]]; then
        error "No suitable disks found for installation!"
    fi
    
    # Show which disk will be used
    local target_disk=""
    if [[ -e /dev/vda ]]; then
        target_disk="/dev/vda"
    elif [[ -e /dev/sda ]]; then
        target_disk="/dev/sda"
    elif [[ -e /dev/nvme0n1 ]]; then
        target_disk="/dev/nvme0n1"
    fi
    
    if [[ -n "$target_disk" ]]; then
        log "Target disk will be: $target_disk"
    fi
    
    if [[ "${AUTO_CONFIRM:-}" != "yes" ]]; then
        warn "Disko will auto-detect and use the first available disk"
        warn "This will DESTROY ALL DATA on the selected disk!"
        read -r -p "Continue with auto-detection? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || error "Installation cancelled"
    fi
    
    log "Proceeding with disk setup..."
}

# Use Disko for partitioning and mounting
setup_disko() {
    log "Setting up disk partitioning and mounting with Disko..."
    
    # Unmount any existing mounts
    umount -R /mnt 2>/dev/null || true
    
    # Run Disko to partition and mount the disk
    # This will use the disko-config.nix for auto-detection and BTRFS setup
    if ! nix run --extra-experimental-features "nix-command flakes" --no-write-lock-file "${FLAKE_URI}#disko" -- --mode disko --flake "${FLAKE_URI}#default"; then
        error "Disko partitioning failed"
    fi
    
    # Verify mounts were created by Disko
    mountpoint -q /mnt || error "Root filesystem not mounted by Disko"
    mountpoint -q /mnt/boot || error "Boot filesystem not mounted by Disko"
    
    log "Disko partitioning and mounting complete ✓"
    
    # Show the disk layout
    log "Final disk layout:"
    lsblk
    
    log "Mounted filesystems:"
    df -h /mnt /mnt/boot /mnt/home /mnt/nix /mnt/var/log 2>/dev/null || df -h /mnt /mnt/boot
}

# Install NixOS
install_nixos() {
    local config="$1"
    local user
    local password
    local password_hash

    # Prompt for username
    while true; do
        read -r -p "Enter username for the new system (e.g., amoon): " user_input
        if [[ -n "$user_input" ]]; then
            user="$user_input"
            break
        else
            warn "Username cannot be empty."
        fi
    done

    # Prompt for password
    while true; do
        read -r -s -p "Enter password for $user: " password_input
        echo
        read -r -s -p "Confirm password: " password_confirm
        echo
        if [[ "$password_input" == "$password_confirm" && -n "$password_input" ]]; then
            password="$password_input"
            break
        else
            warn "Passwords do not match or are empty. Please try again."
        fi
    done

    log "Installing NixOS with configuration: $config"
    log "Setting up user: $user"

    # Generate hardware config (Disko handles filesystem configuration)
    nixos-generate-config --root /mnt --no-filesystems

    # Hash password using mkpasswd from the mkpasswd package
    password_hash=$(nix shell nixpkgs#mkpasswd --no-write-lock-file -c mkpasswd -m sha-512 "$password")

    # Create user-specific configuration file
    cat > /mnt/etc/nixos/user-config.nix << EOF
# User configuration for installation
{
  username = "$user";
  hashedPassword = "$password_hash";
}
EOF

    # Create a simple bootstrap configuration that will use the flake after installation
    cat > /mnt/etc/nixos/configuration.nix << EOF
# Bootstrap NixOS Configuration
{ config, pkgs, lib, ... }:

let
  userConfig = import ./user-config.nix;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Networking
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  
  # Locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  
  # User configuration
  users.users.\${userConfig.username} = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = [ "wheel" "networkmanager" ] ++ 
      (lib.optionals ("${config}" == "server") [ "docker" ]);
    shell = pkgs.zsh;
    hashedPassword = userConfig.hashedPassword;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
    ];
  };
  
  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  
  # Shell
  programs.zsh.enable = true;
  security.sudo.wheelNeedsPassword = true;
  
  # Essential packages
  environment.systemPackages = with pkgs; [
    vim git curl wget htop tree unzip which
  ];
  
  # Nix configuration with flakes
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  # Profile-specific configuration
  virtualisation.docker.enable = lib.mkIf ("${config}" == "server") true;
  
  # Workstation-specific services
  services.xserver.enable = lib.mkIf ("${config}" == "workstation") true;
  services.displayManager.sddm.enable = lib.mkIf ("${config}" == "workstation") true;
  services.desktopManager.plasma6.enable = lib.mkIf ("${config}" == "workstation") true;
  services.pipewire.enable = lib.mkIf ("${config}" == "workstation") true;
  security.rtkit.enable = lib.mkIf ("${config}" == "workstation") true;
  services.printing.enable = lib.mkIf ("${config}" == "workstation") true;
  
  system.stateVersion = "25.05";
}
EOF

    # Create a post-installation script to switch to flake configuration
    cat > /mnt/etc/nixos/switch-to-flake.sh << 'EOF'
#!/bin/bash
# Post-installation script to switch to flake configuration

set -euo pipefail

FLAKE_URI="github:anthonymoon/nixos-config"
CONFIG_TYPE="$(cat /etc/nixos/selected-profile)"

echo "Switching to flake configuration..."
echo "Profile: $CONFIG_TYPE"

# Clone the flake configuration
cd /etc/nixos
if [[ ! -d nixos-config ]]; then
    git clone https://github.com/anthonymoon/nixos-config.git
fi
cd nixos-config

# Switch to flake configuration
sudo nixos-rebuild switch --flake ".#$CONFIG_TYPE"

echo "Successfully switched to flake configuration!"
echo "The system is now using the full flake-based configuration."
EOF

    # Store the selected profile for later use
    echo "$config" > /mnt/etc/nixos/selected-profile
    
    # Make the script executable
    chmod +x /mnt/etc/nixos/switch-to-flake.sh

    # Install with the bootstrap configuration
    if ! nixos-install \
        --no-root-passwd \
        --option extra-substituters "https://cache.nixos.org"; then
        error "NixOS installation failed"
    fi
    
    log "NixOS installation completed successfully ✓"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉 INSTALLATION COMPLETE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}Username:${NC} $user"
    echo -e "${BLUE}Password:${NC} (set during installation)"
    echo -e "${BLUE}Configuration:${NC} $config (bootstrap)"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    log "SSH key will be automatically generated on first boot"
    log "After first boot, run: sudo /etc/nixos/switch-to-flake.sh"
    log "This will switch to the full flake-based configuration"
    echo ""
}

# Main installation flow
main() {
    local config
    
    log "🚀 Starting bulletproof NixOS installation..."
    
    check_installer
    config=$(select_config "$@")
    detect_disk
    setup_disko
    install_nixos "$config"
    
    echo ""
    log "🎉 Installation complete!"
    log "Configuration: $config"
    log "Disk: Auto-detected by Disko"
    warn "Please reboot to start your new NixOS system"
    echo ""
}

# Run main function with all arguments
main "$@"
