#!/usr/bin/env bash
# Setup remote access to NixOS VM
# Host: cachy.local -> VM: nixos@10.10.10.180

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
VM_PASSWORD="M00nsh0t"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_PUB_KEY="$HOME/.ssh/id_ed25519.pub"

log "🚀 Setting up remote access to NixOS VM at $VM_IP"

# Check if we're on cachy.local
if [[ "$(hostname)" != "cachy.local" ]]; then
    warn "Expected to run on cachy.local, but hostname is $(hostname)"
    read -p "Continue anyway? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

# Generate SSH key if it doesn't exist
if [[ ! -f "$SSH_KEY" ]]; then
    log "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$(whoami)@cachy.local"
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

# Copy SSH key to VM using sshpass
log "Installing SSH public key to VM..."
if ! command -v sshpass >/dev/null 2>&1; then
    warn "sshpass not found. Installing..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm sshpass
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y sshpass
    else
        error "Cannot install sshpass. Please install it manually."
    fi
fi

# Copy SSH key using password authentication
log "Copying SSH key to $VM_USER@$VM_IP..."
if sshpass -p "$VM_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "$VM_USER@$VM_IP"; then
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

# Create convenience functions script
log "Creating VM management script..."
cat > "$HOME/vm-control.sh" << 'EOF'
#!/usr/bin/env bash
# VM Control Script for NixOS VM

VM_IP="10.10.10.180"
VM_USER="nixos"
VM_NAME="nixos"  # Adjust if your VM has a different name

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

vm_ssh() {
    echo -e "${GREEN}[SSH]${NC} Connecting to $VM_USER@$VM_IP..."
    ssh -o ConnectTimeout=5 "$VM_USER@$VM_IP" "$@"
}

vm_exec() {
    echo -e "${GREEN}[EXEC]${NC} Running on VM: $*"
    ssh -o ConnectTimeout=5 "$VM_USER@$VM_IP" "$@"
}

vm_copy() {
    local src="$1"
    local dest="$2"
    echo -e "${GREEN}[COPY]${NC} $src -> $VM_USER@$VM_IP:$dest"
    scp -o ConnectTimeout=5 "$src" "$VM_USER@$VM_IP:$dest"
}

vm_status() {
    echo -e "${BLUE}[STATUS]${NC} Checking VM status..."
    if ping -c 1 -W 2 "$VM_IP" >/dev/null 2>&1; then
        echo "✅ VM is reachable at $VM_IP"
        if ssh -o ConnectTimeout=2 "$VM_USER@$VM_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
            echo "✅ SSH access working"
        else
            echo "❌ SSH access failed"
        fi
    else
        echo "❌ VM is not reachable"
    fi
}

vm_virsh() {
    echo -e "${BLUE}[VIRSH]${NC} Running virsh command: $*"
    sudo virsh "$@"
}

vm_start() {
    echo -e "${GREEN}[START]${NC} Starting VM..."
    sudo virsh start "$VM_NAME" || echo "VM might already be running"
}

vm_stop() {
    echo -e "${GREEN}[STOP]${NC} Stopping VM..."
    sudo virsh shutdown "$VM_NAME"
}

vm_restart() {
    echo -e "${GREEN}[RESTART]${NC} Restarting VM..."
    sudo virsh reboot "$VM_NAME"
}

vm_console() {
    echo -e "${GREEN}[CONSOLE]${NC} Connecting to VM console (Ctrl+] to exit)..."
    sudo virsh console "$VM_NAME"
}

# Main command dispatcher
case "${1:-help}" in
    ssh)
        shift
        vm_ssh "$@"
        ;;
    exec)
        shift
        vm_exec "$@"
        ;;
    copy)
        vm_copy "$2" "$3"
        ;;
    status)
        vm_status
        ;;
    start)
        vm_start
        ;;
    stop)
        vm_stop
        ;;
    restart)
        vm_restart
        ;;
    console)
        vm_console
        ;;
    virsh)
        shift
        vm_virsh "$@"
        ;;
    help|*)
        echo "VM Control Script"
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  ssh [cmd]       - SSH to VM (optionally run command)"
        echo "  exec <cmd>      - Execute command on VM"
        echo "  copy <src> <dst> - Copy file to VM"
        echo "  status          - Check VM connectivity"
        echo "  start           - Start VM via virsh"
        echo "  stop            - Stop VM via virsh"
        echo "  restart         - Restart VM via virsh"
        echo "  console         - Connect to VM console"
        echo "  virsh <cmd>     - Run virsh command"
        echo ""
        echo "Examples:"
        echo "  $0 ssh                    # Interactive SSH"
        echo "  $0 exec 'sudo reboot'    # Reboot VM"
        echo "  $0 copy script.sh /tmp/   # Copy file"
        echo "  $0 status                 # Check status"
        ;;
esac
EOF

chmod +x "$HOME/vm-control.sh"

log "✅ VM control script created at $HOME/vm-control.sh"

# Test the setup
log "Testing complete setup..."
echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  🎉 VM ACCESS SETUP COMPLETE${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo "VM Information:"
echo "  IP: $VM_IP"
echo "  User: $VM_USER"
echo "  SSH Key: $SSH_KEY"
echo ""
echo "Quick Commands:"
echo "  SSH to VM:           ssh $VM_USER@$VM_IP"
echo "  VM Control Script:   ~/vm-control.sh"
echo ""
echo "Examples:"
echo "  ~/vm-control.sh ssh                    # Interactive SSH"
echo "  ~/vm-control.sh exec 'sudo reboot'    # Reboot VM"
echo "  ~/vm-control.sh status                # Check status"
echo "  ~/vm-control.sh console               # Console access"
echo ""

# Final connectivity test
if "$HOME/vm-control.sh" status; then
    log "🎉 Setup successful! You now have remote access to the NixOS VM."
else
    warn "Setup completed but connectivity test failed. Check VM status."
fi