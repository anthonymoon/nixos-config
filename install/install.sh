#!/usr/bin/env bash
# Bulletproof NixOS Installer - Zero-Failure Architecture
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
        read -p "Select a configuration [vm/workstation/server]: " choice
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
    local disk_count=$(lsblk -d -o TYPE | grep -E "disk|nvme" | grep -v -E "rom|loop" | wc -l)
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
        read -p "Continue with auto-detection? [y/N]: " confirm
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
        read -p "Enter username for the new system (e.g., amoon): " user_input
        if [[ -n "$user_input" ]]; then
            user="$user_input"
            break
        else
            warn "Username cannot be empty."
        fi
    done

    # Prompt for password
    while true; do
        read -s -p "Enter password for $user: " password_input
        echo
        read -s -p "Confirm password: " password_confirm
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

    # Hash password using mkpasswd from whois package
    password_hash=$(nix shell nixpkgs#whois --no-write-lock-file -c mkpasswd -m sha-512 "$password")

    # Create user configuration file that will be imported by base.nix
    cat > /mnt/etc/nixos/user-config.nix << EOF
# User Configuration - Generated during installation
{ config, pkgs, lib, ... }:

{
  # User account configuration
  users.users.${user} = {
    isNormalUser = true;
    description = "Primary User";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    hashedPassword = "${password_hash}";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us"
    ];
    createHome = true;
  };

  # Home Manager integration for this user
  home-manager.users.${user} = import ${FLAKE_URI}/modules/home.nix;

  # Automatic SSH key generation service
  systemd.services.generate-user-ssh-key = {
    description = "Generate SSH key for ${user} on first boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "${user}";
      Group = "users";
      ExecStart = pkgs.writeShellScript "generate-ssh-key" ''
        set -euo pipefail
        
        SSH_DIR="/home/${user}/.ssh"
        SSH_KEY="\$SSH_DIR/id_ed25519"
        
        # Only generate if key doesn't exist
        if [[ ! -f "\$SSH_KEY" ]]; then
          echo "Generating SSH key for ${user}..."
          mkdir -p "\$SSH_DIR"
          \${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "\$SSH_KEY" -N "" -C "${user}@nixos"
          chmod 700 "\$SSH_DIR"
          chmod 600 "\$SSH_KEY"
          chmod 644 "\$SSH_KEY.pub"
          echo "SSH key generated successfully"
        else
          echo "SSH key already exists, skipping generation"
        fi
      '';
    };
  };
}
EOF

    # Create a minimal configuration.nix that just imports hardware config
    cat > /mnt/etc/nixos/configuration.nix << EOF
# Minimal NixOS Configuration
# This file is required by nixos-install but all configuration
# is handled by the flake and user-config.nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];
  
  # Empty - all configuration handled by flake
}
EOF
    
    # Install with selected configuration using refresh flag
    # Use explicit fragment syntax to avoid parsePathFlakeRefWithFragment bug
    if ! nixos-install --flake "${FLAKE_URI}#$config" --no-root-passwd --no-write-lock-file --option extra-substituters "https://cache.nixos.org" --refresh; then
        error "NixOS installation failed"
    fi
    
    log "NixOS installation completed successfully ✓"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉 INSTALLATION COMPLETE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}Username:${NC} $user"
    echo -e "${BLUE}Password:${NC} (set during installation)"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    log "SSH key will be automatically generated on first boot"
    log "Post-installation setup is now handled declaratively by NixOS"
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
