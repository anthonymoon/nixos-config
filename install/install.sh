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

# Simplified disk partitioning - Always GPT, XFS root, 1GB EFI
partition_disk() {
    local disk="$1"
    
    warn "This will DESTROY ALL DATA on $disk!"
    if [[ "${AUTO_CONFIRM:-}" != "yes" ]]; then
        read -p "Continue? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || error "Installation cancelled"
    fi
    
    log "Partitioning $disk with GPT..."
    
    # Unmount any existing mounts
    umount -R /mnt 2>/dev/null || true
    
    # Wipe disk completely
    wipefs -af "$disk"
    sgdisk --zap-all "$disk"
    
    # Create GPT partition table
    parted "$disk" --script -- mklabel gpt
    
    # Create 1GB EFI System Partition (properly aligned)
    parted "$disk" --script -- mkpart ESP fat32 1MiB 1025MiB
    parted "$disk" --script -- set 1 esp on
    
    # Create XFS root partition (remaining space, properly aligned)
    parted "$disk" --script -- mkpart primary xfs 1025MiB 100%
    
    # Wait for kernel to recognize partitions
    sleep 2
    partprobe "$disk"
    sleep 2
    
    # Verify partitions exist
    local boot_part="${disk}1"
    local root_part="${disk}2"
    
    [[ -b "$boot_part" ]] || error "Boot partition $boot_part not created"
    [[ -b "$root_part" ]] || error "Root partition $root_part not created"
    
    # Format filesystems - FAT32 EFI, XFS root
    log "Formatting filesystems..."
    mkfs.fat -F32 -n boot "$boot_part"
    
    # Load XFS module for the installer
    modprobe xfs || warn "Could not load XFS module"
    
    mkfs.xfs -f -L nixos "$root_part"
    
    log "Partitioning complete ✓"
    lsblk "$disk"
}

# Mount filesystems
mount_filesystems() {
    log "Mounting filesystems..."
    
    # Ensure XFS module is loaded
    modprobe xfs || warn "Could not load XFS module"
    
    # Wait for labels to appear
    sleep 3
    
    # Mount root - try by label first, fallback to partition
    if [[ -e /dev/disk/by-label/nixos ]]; then
        mount /dev/disk/by-label/nixos /mnt
    else
        warn "Label not found, mounting by partition"
        mount "${DISK}2" /mnt
    fi
    
    # Create and mount boot
    mkdir -p /mnt/boot
    if [[ -e /dev/disk/by-label/boot ]]; then
        mount /dev/disk/by-label/boot /mnt/boot
    else
        warn "Boot label not found, mounting by partition"
        mount "${DISK}1" /mnt/boot
    fi
    
    # Verify mounts
    mountpoint -q /mnt || error "Root filesystem not mounted"
    mountpoint -q /mnt/boot || error "Boot filesystem not mounted"
    
    log "Filesystems mounted ✓"
    df -h /mnt /mnt/boot
}

# Install NixOS
install_nixos() {
    local config="$1"
    local user="${INSTALL_USER:-amoon}"  # Use env var or default to "amoon"
    
    log "Installing NixOS with configuration: $config"
    log "Setting up user: $user"
    
    # Generate hardware config and create custom configuration
    nixos-generate-config --root /mnt
    
    # Generate random password for user (using /dev/urandom)
    local password=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
    
    # Hash password using mkpasswd from whois package
    local password_hash=$(nix-shell -p whois --run "echo '$password' | mkpasswd -m sha-512 -s")
    
    # Create configuration.nix that imports our flake and hardware config
    cat > /mnt/etc/nixos/configuration.nix << EOF
# NixOS Configuration - DO NOT EDIT
# This configuration imports the selected profile from the flake
# Edit the flake profiles directly instead of this file
{
  imports = [
    ./hardware-configuration.nix
  ];
  
  # User password configuration
  users.users.$user = {
    hashedPassword = "$password_hash";
  };
  
  # Use the flake configuration
  system.configurationRevision = null;
}
EOF
    
    # Clear Nix evaluation cache for fresh installation (user and root)
    rm -rf ~/.cache/nix/eval-cache-v* 2>/dev/null || true
    rm -rf /root/.cache/nix/eval-cache-v* 2>/dev/null || true
    
    # Install with selected configuration using refresh flag
    # Use explicit fragment syntax to avoid parsePathFlakeRefWithFragment bug
    if ! nixos-install --flake "${FLAKE_URI}#$config" --no-root-passwd --no-write-lock-file --option extra-substituters "https://cache.nixos.org" --refresh; then
        error "NixOS installation failed"
    fi
    
    log "NixOS installation completed successfully ✓"
    
    # Integrated post-installation setup
    log "Running integrated post-installation setup..."
    
    # Set up user shell in chroot
    if nixos-enter --root /mnt -- command -v zsh >/dev/null 2>&1; then
        nixos-enter --root /mnt -- chsh -s "$(nixos-enter --root /mnt -- which zsh)" "$user" || warn "Failed to set zsh as default shell"
    fi
    
    # Generate SSH key for user
    if [[ ! -f "/mnt/home/$user/.ssh/id_ed25519" ]]; then
        log "Generating SSH key for user $user..."
        nixos-enter --root /mnt -- sudo -u "$user" mkdir -p "/home/$user/.ssh"
        nixos-enter --root /mnt -- sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N "" -C "$user@nixos"
        nixos-enter --root /mnt -- sudo -u "$user" chmod 700 "/home/$user/.ssh"
        nixos-enter --root /mnt -- sudo -u "$user" chmod 600 "/home/$user/.ssh/id_ed25519"
        nixos-enter --root /mnt -- sudo -u "$user" chmod 644 "/home/$user/.ssh/id_ed25519.pub"
    fi
    
    # Configuration-specific setup
    case "$config" in
        "workstation")
            log "Setting up workstation-specific configurations..."
            nixos-enter --root /mnt -- sudo -u "$user" mkdir -p "/home/$user/Development" "/home/$user/Projects" "/home/$user/Downloads" || warn "Failed to create directories"
            ;;
        "server")
            log "Setting up server-specific configurations..."
            nixos-enter --root /mnt -- mkdir -p /var/log/custom /opt/scripts || warn "Failed to create server directories"
            
            # Set up logrotate for custom logs
            nixos-enter --root /mnt -- tee /etc/logrotate.d/custom-logs >/dev/null <<'LOGROTATE_EOF'
/var/log/custom/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
}
LOGROTATE_EOF
            ;;
        "vm")
            log "VM-specific setup completed during installation..."
            ;;
    esac
    
    # Cleanup
    log "Cleaning up installation artifacts..."
    nixos-enter --root /mnt -- nix-collect-garbage -d || warn "Failed to collect garbage"
    nixos-enter --root /mnt -- nix-store --optimize || warn "Failed to optimize store"
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  🔑 LOGIN CREDENTIALS${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}Username:${NC} $user"
    echo -e "${BLUE}Password:${NC} $password"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Display SSH public key if generated
    if [[ -f "/mnt/home/$user/.ssh/id_ed25519.pub" ]]; then
        echo -e "${BLUE}SSH Public Key (add to GitHub/servers):${NC}"
        cat "/mnt/home/$user/.ssh/id_ed25519.pub"
        echo ""
    fi
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
