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
    
    # Always proceed without confirmation
    log "Auto-detecting and using the first available disk"
    warn "This will DESTROY ALL DATA on the selected disk!"
    
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

    log "Installing NixOS with configuration: $config"
    log "Users will be created: root, nixos, amoon (with SSH keys)"

    # Generate hardware config (Disko handles filesystem configuration)
    nixos-generate-config --root /mnt --no-filesystems

    # No need to create user configuration - handled in base.nix

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
    
    # Install with selected configuration
    # Use explicit fragment syntax to avoid parsePathFlakeRefWithFragment bug
    if ! nixos-install --flake "${FLAKE_URI}#$config" --no-root-passwd --no-write-lock-file --option extra-substituters "https://cache.nixos.org"; then
        error "NixOS installation failed"
    fi
    
    log "NixOS installation completed successfully ✓"
    
    # Update EFI boot order to ensure systemd-boot is first
    log "Updating EFI boot order..."
    if command -v efibootmgr &> /dev/null; then
        # Find the systemd-boot entry
        local boot_entry=$(efibootmgr | grep -i "Linux Boot Manager" | grep -o "Boot[0-9A-F]*" | head -1 | sed 's/Boot//')
        if [[ -n "$boot_entry" ]]; then
            log "Found systemd-boot entry: Boot${boot_entry}"
            # Set it as the first boot option
            efibootmgr -o "${boot_entry}" 2>/dev/null || warn "Failed to update boot order (may already be correct)"
            log "EFI boot order updated ✓"
        else
            warn "Could not find systemd-boot entry in EFI variables"
        fi
        
        # Show current boot order
        log "Current EFI boot configuration:"
        efibootmgr | grep -E "BootOrder|Boot[0-9A-F]*\*" || true
    else
        warn "efibootmgr not available - please manually ensure boot order is correct"
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉 INSTALLATION COMPLETE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}Users:${NC} root, nixos, amoon"
    echo -e "${BLUE}SSH Key:${NC} Already configured for all users"
    echo -e "${BLUE}Initial Password:${NC} Empty (set one after boot)"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    log "SSH key will be automatically generated on first boot"
    log "Post-installation setup is now handled declaratively by NixOS"
    echo ""
}

# Main installation flow
main() {
    if [[ $# -eq 0 ]]; then
        error "No configuration profile specified. Usage: ./install.sh <profile>"
    fi
    local config="$1"
    
    log "🚀 Starting bulletproof NixOS installation for profile: $config..."
    
    check_installer
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
