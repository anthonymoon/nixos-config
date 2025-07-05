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
DISK="${DISK:-/dev/vda}"
FLAKE_REPO="github:anthonymoon/nixos-config"

# Available configurations
declare -A CONFIGS=(
    ["1"]="vm-minimal:Minimal VM setup (no desktop)"
    ["2"]="vm-workstation:VM with full desktop environment"  
    ["3"]="vm-server:VM optimized for server workloads"
    ["4"]="workstation:Physical machine with desktop"
    ["5"]="server:Physical machine for server use"
    ["6"]="minimal:Physical machine minimal setup"
)

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
    for key in $(printf '%s\n' "${!CONFIGS[@]}" | sort); do
        IFS=':' read -r config desc <<< "${CONFIGS[$key]}"
        printf "%s) %-15s - %s\n" "$key" "$config" "$desc"
    done
    echo "────────────────────────────────────────"
    
    while true; do
        read -p "Select configuration [1-6]: " choice
        if [[ -n "${CONFIGS[$choice]:-}" ]]; then
            IFS=':' read -r config desc <<< "${CONFIGS[$choice]}"
            echo "$config"
            return
        fi
        warn "Invalid choice. Please select 1-6."
    done
}

# Detect disk or use provided one
detect_disk() {
    if [[ -b "$DISK" ]]; then
        log "Using disk: $DISK"
        return
    fi
    
    warn "Disk $DISK not found. Available disks:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    
    read -p "Enter disk path (e.g., /dev/sda): " DISK
    if [[ ! -b "$DISK" ]]; then
        error "Disk $DISK not found"
    fi
}

# Bulletproof disk partitioning
partition_disk() {
    local disk="$1"
    
    warn "This will DESTROY ALL DATA on $disk!"
    if [[ "${AUTO_CONFIRM:-}" != "yes" ]]; then
        read -p "Continue? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || error "Installation cancelled"
    fi
    
    log "Partitioning $disk..."
    
    # Unmount any existing mounts
    umount -R /mnt 2>/dev/null || true
    
    # Wipe disk completely
    wipefs -af "$disk"
    sgdisk --zap-all "$disk"
    
    # Create GPT partition table
    parted "$disk" --script -- mklabel gpt
    
    # Create EFI System Partition (512MB)
    parted "$disk" --script -- mkpart ESP fat32 1MB 513MB
    parted "$disk" --script -- set 1 esp on
    
    # Create root partition (remaining space)
    parted "$disk" --script -- mkpart primary 513MB 100%
    
    # Wait for kernel to recognize partitions
    sleep 2
    partprobe "$disk"
    sleep 2
    
    # Verify partitions exist
    local boot_part="${disk}1"
    local root_part="${disk}2"
    
    [[ -b "$boot_part" ]] || error "Boot partition $boot_part not created"
    [[ -b "$root_part" ]] || error "Root partition $root_part not created"
    
    # Format with predictable labels (KEY: Always use labels, never UUIDs)
    log "Formatting filesystems..."
    mkfs.fat -F32 -n boot "$boot_part"
    mkfs.ext4 -L nixos "$root_part"
    
    log "Partitioning complete ✓"
    lsblk "$disk"
}

# Mount filesystems
mount_filesystems() {
    log "Mounting filesystems..."
    
    # Mount root
    mount /dev/disk/by-label/nixos /mnt
    
    # Create and mount boot
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
    
    # Verify mounts
    mountpoint -q /mnt || error "Root filesystem not mounted"
    mountpoint -q /mnt/boot || error "Boot filesystem not mounted"
    
    log "Filesystems mounted ✓"
    df -h /mnt /mnt/boot
}

# Install NixOS
install_nixos() {
    local config="$1"
    
    log "Installing NixOS with configuration: $config"
    
    # Generate minimal hardware config (just for compatibility)
    nixos-generate-config --root /mnt
    
    # Install with selected configuration
    if ! nixos-install --flake "$FLAKE_REPO#$config" --no-root-passwd; then
        error "NixOS installation failed"
    fi
    
    log "NixOS installation completed successfully ✓"
}

# Main installation flow
main() {
    local config
    
    log "🚀 Starting bulletproof NixOS installation..."
    
    check_installer
    config=$(select_config "$@")
    detect_disk
    partition_disk "$DISK"
    mount_filesystems
    install_nixos "$config"
    
    echo ""
    log "🎉 Installation complete!"
    log "Configuration: $config"
    log "Disk: $DISK"
    warn "Please reboot to start your new NixOS system"
    echo ""
}

# Run main function with all arguments
main "$@"