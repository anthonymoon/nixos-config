#!/usr/bin/env bash
# Post-installation script for additional setup tasks

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# Get configuration from argument
CONFIG="${1:-}"

if [[ -z "$CONFIG" ]]; then
    error "Usage: $0 <configuration_name>"
fi

log "🚀 Starting post-installation setup for: $CONFIG"

# Update system channels
log "Updating system channels..."
sudo nix-channel --update || warn "Failed to update channels"

# Rebuild with latest configuration
log "Rebuilding system with latest configuration..."
if ! sudo nixos-rebuild switch --flake ".#$CONFIG" --upgrade; then
    warn "System rebuild failed, trying without upgrade..."
    sudo nixos-rebuild switch --flake ".#$CONFIG" || error "System rebuild failed completely"
fi

# Set up user shell
log "Setting up user shell..."
if command -v zsh >/dev/null 2>&1; then
    sudo chsh -s "$(which zsh)" "$USER" || warn "Failed to set zsh as default shell"
fi

# Generate SSH key if it doesn't exist
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    log "Generating SSH key..."
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$USER@$(hostname)"
    log "SSH public key:"
    cat "$HOME/.ssh/id_ed25519.pub"
fi

# Configuration-specific setup
case "$CONFIG" in
    "workstation")
        log "Setting up workstation-specific configurations..."
        
        # Enable flathub for additional software
        if command -v flatpak >/dev/null 2>&1; then
            log "Adding Flathub repository..."
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || warn "Failed to add Flathub"
        fi
        
        # Set up development directories
        mkdir -p "$HOME/Development" "$HOME/Projects" "$HOME/Downloads" || warn "Failed to create directories"
        ;;
        
    "server")
        log "Setting up server-specific configurations..."
        
        # Create common server directories
        sudo mkdir -p /var/log/custom /opt/scripts || warn "Failed to create server directories"
        
        # Set up logrotate for custom logs
        if [[ -d /etc/logrotate.d ]]; then
            sudo tee /etc/logrotate.d/custom-logs >/dev/null <<EOF
/var/log/custom/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF
        fi
        ;;
        
    "vm")
        log "Setting up VM-specific configurations..."
        
        # Install QEMU guest agent if not present
        if ! systemctl is-active --quiet qemu-guest-agent; then
            warn "QEMU guest agent not running"
        fi
        ;;
esac

# Cleanup
log "Cleaning up..."
sudo nix-collect-garbage -d || warn "Failed to collect garbage"
sudo nix-store --optimize || warn "Failed to optimize store"

# Display system information
log "🎉 Post-installation complete!"
echo ""
echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  User: $USER"
echo "  Configuration: $CONFIG"
echo "  NixOS Version: $(nixos-version)"
echo ""

if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    echo "SSH Public Key (add this to GitHub/servers):"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
fi

log "Please reboot the system to ensure all changes take effect."