#!/usr/bin/env bash
# Simplified VM Access Setup
# Sets up SSH key authentication for NixOS VM

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

# Configuration
VM_IP="10.10.10.180"
VM_USER="nixos"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PUB_KEY="$HOME/.ssh/id_ed25519.pub"

log "🚀 Setting up SSH access to NixOS VM at $VM_IP"

# Generate SSH key if it doesn't exist
if [[ ! -f "$SSH_KEY" ]]; then
    log "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$(whoami)@$(hostname)"
fi

# Check if SSH key exists
if [[ ! -f "$SSH_PUB_KEY" ]]; then
    error "SSH public key not found at $SSH_PUB_KEY"
fi

log "Using SSH public key: $SSH_PUB_KEY"
cat "$SSH_PUB_KEY"
echo ""

# Test VM connectivity
log "Testing connectivity to VM..."
if ! ping -c 1 -W 2 "$VM_IP" >/dev/null 2>&1; then
    error "Cannot reach VM at $VM_IP. Is the VM running?"
fi

# Check if sshpass is available for initial setup
if ! command -v sshpass >/dev/null 2>&1; then
    warn "sshpass not found. You'll need to manually copy the SSH key."
    echo ""
    echo "Manual setup instructions:"
    echo "1. SSH to the VM manually: ssh $VM_USER@$VM_IP"
    echo "2. Create .ssh directory: mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    echo "3. Add your public key to authorized_keys:"
    echo "   echo '$(cat "$SSH_PUB_KEY")' >> ~/.ssh/authorized_keys"
    echo "4. Set permissions: chmod 600 ~/.ssh/authorized_keys"
    echo ""
    echo "After manual setup, test with: ssh $VM_USER@$VM_IP"
    exit 0
fi

# Try to copy SSH key (requires VM password)
log "Copying SSH key to $VM_USER@$VM_IP..."
echo "Enter the VM password when prompted:"
if ssh-copy-id -o StrictHostKeyChecking=no "$VM_USER@$VM_IP"; then
    log "✅ SSH key successfully copied to VM"
else
    error "Failed to copy SSH key to VM"
fi

# Test passwordless SSH
log "Testing passwordless SSH access..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "echo 'SSH access successful'" >/dev/null 2>&1; then
    log "✅ Passwordless SSH access working"
else
    error "Passwordless SSH access failed"
fi

# Provide SSH config instructions
echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  🎉 SSH SETUP COMPLETE${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo "Add this to your ~/.ssh/config for easy access:"
echo ""
echo "Host nixos-vm"
echo "    HostName $VM_IP"
echo "    User $VM_USER"
echo "    IdentityFile $SSH_KEY"
echo ""
echo "Then connect with: ssh nixos-vm"
echo ""
echo "Direct connection: ssh $VM_USER@$VM_IP"
echo ""

log "🎉 VM SSH access setup complete!"