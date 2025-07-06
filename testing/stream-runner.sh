#!/usr/bin/env bash
# Streaming Test Runner with Structured Output
# Provides real-time monitoring of NixOS installation with parseable progress

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_MANAGER="$SCRIPT_DIR/vm-manager.sh"
LOG_DIR="/tmp/nixos-testing/logs"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Structured output functions
emit_phase() { echo "::PHASE::$1"; }
emit_progress() { echo "::PROGRESS::$1::$2"; }
emit_success() { echo "::SUCCESS::$1"; }
emit_warning() { echo "::WARNING::$1"; }
emit_error() { echo "::ERROR::$1"; }
emit_context() { echo "::CONTEXT::$1"; }
emit_metric() { echo "::METRIC::$1::$2"; }

log() { echo -e "${GREEN}[STREAM]${NC} $1"; }
warn() { echo -e "${YELLOW}[STREAM]${NC} $1"; emit_warning "$1"; }
error() { echo -e "${RED}[STREAM]${NC} $1"; emit_error "$1"; exit 1; }

# Enhanced installer wrapper with structured output
create_monitored_installer() {
    local profile="$1"
    local output_file="$2"
    
    cat > "$output_file" << 'EOF'
#!/usr/bin/env bash
# Monitored Installer Wrapper - Injects structured output into install.sh

set -euo pipefail

PROFILE="$1"
ORIGINAL_INSTALLER="/tmp/nixos-config/install/install.sh"

# Structured output functions
emit_phase() { echo "::PHASE::$1" >&2; }
emit_progress() { echo "::PROGRESS::$1::$2" >&2; }
emit_success() { echo "::SUCCESS::$1" >&2; }
emit_error() { echo "::ERROR::$1" >&2; }
emit_context() { echo "::CONTEXT::$1" >&2; }

# Monitoring functions
monitor_disk_usage() {
    local mount_point="$1"
    if mountpoint -q "$mount_point" 2>/dev/null; then
        local usage=$(df "$mount_point" | awk 'NR==2 {print $5}' | tr -d '%')
        if [[ "$usage" -gt 80 ]]; then
            emit_context "DISK_USAGE_HIGH::$mount_point::${usage}%"
        fi
    fi
}

monitor_memory_usage() {
    local mem_info=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [[ "$mem_info" -gt 85 ]]; then
        emit_context "MEMORY_USAGE_HIGH::${mem_info}%"
    fi
}

# Hook into key installation phases
emit_phase "INITIALIZATION"
emit_progress "STARTING" "Installing NixOS profile: $PROFILE"

# Check system resources
monitor_memory_usage
emit_context "SYSTEM_MEMORY::$(free -h | awk 'NR==2{print $2}')"
emit_context "AVAILABLE_DISKS::$(lsblk -d -o NAME,SIZE | grep -v NAME | wc -l)"

# Patch the installer to emit structured output
if [[ -f "$ORIGINAL_INSTALLER" ]]; then
    # Create a wrapper that monitors the original installer
    exec > >(tee /tmp/installer.log)
    exec 2> >(tee /tmp/installer.err >&2)
    
    # Pre-installation monitoring
    emit_phase "PRE_INSTALLATION_CHECKS"
    
    # Monitor available space
    emit_context "ROOT_AVAILABLE::$(df / | awk 'NR==2 {print $4}')"
    
    # Check network connectivity
    if ping -c 1 cache.nixos.org >/dev/null 2>&1; then
        emit_success "NETWORK_CONNECTIVITY_OK"
    else
        emit_error "NETWORK_CONNECTIVITY_FAILED"
    fi
    
    # Start the actual installer with monitoring
    emit_phase "DISK_PARTITIONING"
    
    # Create a named pipe for monitoring installer output
    mkfifo /tmp/installer_pipe
    
    # Run installer and monitor its output
    (
        # Monitor for key patterns in installer output
        while IFS= read -r line; do
            echo "$line"  # Pass through original output
            
            # Pattern matching for structured events
            case "$line" in
                *"Setting up disk partitioning"*)
                    emit_phase "DISKO_PARTITIONING"
                    ;;
                *"partitioning complete"*)
                    emit_success "DISK_PARTITIONING_COMPLETE"
                    ;;
                *"Mounting filesystems"*)
                    emit_phase "FILESYSTEM_MOUNTING"
                    ;;
                *"Filesystems mounted"*)
                    emit_success "FILESYSTEM_MOUNTING_COMPLETE"
                    ;;
                *"Installing NixOS"*)
                    emit_phase "NIXOS_INSTALLATION"
                    ;;
                *"installation completed successfully"*)
                    emit_success "NIXOS_INSTALLATION_COMPLETE"
                    ;;
                *"Cleaning up"*)
                    emit_phase "POST_INSTALL_CLEANUP"
                    ;;
                *"ERROR"*)
                    emit_error "INSTALLER_ERROR::$line"
                    ;;
                *"WARN"*)
                    emit_context "INSTALLER_WARNING::$line"
                    ;;
                *"failed"*|*"error"*|*"Error"*)
                    emit_error "INSTALLATION_FAILURE::$line"
                    ;;
            esac
            
            # Monitor system resources during installation
            monitor_disk_usage "/mnt"
            monitor_memory_usage
            
        done < /tmp/installer_pipe
    ) &
    
    # Run the actual installer
    bash "$ORIGINAL_INSTALLER" "$PROFILE" > /tmp/installer_pipe 2>&1
    installer_exit_code=$?
    
    # Clean up
    rm -f /tmp/installer_pipe
    
    if [[ $installer_exit_code -eq 0 ]]; then
        emit_success "INSTALLATION_COMPLETE"
    else
        emit_error "INSTALLATION_FAILED::EXIT_CODE_$installer_exit_code"
        exit $installer_exit_code
    fi
else
    emit_error "INSTALLER_NOT_FOUND::$ORIGINAL_INSTALLER"
    exit 1
fi

emit_phase "INSTALLATION_FINISHED"
EOF
    
    chmod +x "$output_file"
}

# Monitor SSH command output with real-time processing
monitor_ssh_stream() {
    local ip="$1"
    local user="$2"
    local command="$3"
    local log_file="$4"
    
    log "Starting real-time monitoring of: $command"
    
    # Use script command for robust logging with timestamps
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$user@$ip" \
        "script -q -c '$command' /tmp/monitored_install.log && cat /tmp/monitored_install.log" | \
    while IFS= read -r line; do
        # Log to file
        echo "$(date '+%Y-%m-%d %H:%M:%S') $line" >> "$log_file"
        
        # Process structured output
        if [[ "$line" =~ ^::([A-Z_]+)::(.*)$ ]]; then
            local event_type="${BASH_REMATCH[1]}"
            local event_data="${BASH_REMATCH[2]}"
            
            case "$event_type" in
                "PHASE")
                    echo -e "${CYAN}📍 PHASE: $event_data${NC}"
                    ;;
                "SUCCESS")
                    echo -e "${GREEN}✅ SUCCESS: $event_data${NC}"
                    ;;
                "ERROR")
                    echo -e "${RED}❌ ERROR: $event_data${NC}"
                    return 1
                    ;;
                "WARNING")
                    echo -e "${YELLOW}⚠️  WARNING: $event_data${NC}"
                    ;;
                "CONTEXT")
                    echo -e "${BLUE}ℹ️  CONTEXT: $event_data${NC}"
                    ;;
                "PROGRESS")
                    echo -e "${CYAN}⏳ PROGRESS: $event_data${NC}"
                    ;;
                "METRIC")
                    echo -e "${CYAN}📊 METRIC: $event_data${NC}"
                    ;;
            esac
        else
            # Regular output - pass through with timestamp
            echo -e "${NC}$(date '+%H:%M:%S') $line${NC}"
        fi
    done
}

# Run installation test for a profile
test_profile_installation() {
    local profile="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local log_file="$LOG_DIR/${profile}_install_${timestamp}.log"
    
    mkdir -p "$LOG_DIR"
    
    emit_phase "PROFILE_TEST_START"
    emit_progress "TESTING" "Profile: $profile"
    
    log "Testing installation of profile: $profile"
    
    # Step 1: Revert VM to clean state
    emit_phase "VM_PREPARATION"
    "$VM_MANAGER" clean
    
    # Step 2: Start VM
    emit_phase "VM_STARTUP"
    local ip=$("$VM_MANAGER" start)
    emit_success "VM_READY::$ip"
    
    # Step 3: Deploy configuration
    emit_phase "CONFIG_DEPLOYMENT"
    "$VM_MANAGER" deploy "$ip"
    emit_success "CONFIG_DEPLOYED"
    
    # Step 4: Create and deploy monitored installer
    emit_phase "INSTALLER_PREPARATION"
    local monitored_installer="/tmp/monitored_installer_${profile}.sh"
    create_monitored_installer "$profile" "$monitored_installer"
    
    # Copy monitored installer to VM
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$monitored_installer" nixos@"$ip":/tmp/monitored_installer.sh
    
    # Step 5: Run installation with real-time monitoring
    emit_phase "INSTALLATION_EXECUTION"
    
    # Use agent monitor with self-healing if available
    local monitor_cmd="bash"
    if [[ -f "$SCRIPT_DIR/agent-monitor.py" ]]; then
        monitor_cmd="python3 $SCRIPT_DIR/agent-monitor.py $profile --vm-ip $ip bash"
    fi
    
    if $monitor_cmd "$SCRIPT_DIR/stream-runner-internal.sh" "$ip" "$profile" "$log_file"; then
        emit_success "INSTALLATION_SUCCESS::$profile"
        
        # Step 6: Post-installation verification
        emit_phase "POST_INSTALL_VERIFICATION"
        verify_installation "$ip" "$profile"
        
        return 0
    else
        emit_error "INSTALLATION_FAILED::$profile"
        
        # Capture failure context
        emit_context "LOG_LOCATION::$log_file"
        
        return 1
    fi
}

# Verify installation success
verify_installation() {
    local ip="$1"
    local profile="$2"
    
    log "Verifying installation of $profile..."
    
    # Wait for reboot and new system
    emit_phase "REBOOT_WAIT"
    sleep 30  # Give time for installer to trigger reboot
    
    # Wait for system to come back up
    local timeout=300
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
               amoon@"$ip" "echo 'System ready'" >/dev/null 2>&1; then
            emit_success "SYSTEM_REBOOT_COMPLETE"
            break
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        emit_error "REBOOT_TIMEOUT"
        return 1
    fi
    
    # Run basic verification checks
    emit_phase "SYSTEM_VERIFICATION"
    
    # Check filesystem
    local fs_type=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        amoon@"$ip" "stat -f / --format='%T'" 2>/dev/null || echo "unknown")
    
    if [[ "$fs_type" == "btrfs" ]]; then
        emit_success "FILESYSTEM_VERIFICATION::btrfs"
    else
        emit_warning "FILESYSTEM_UNEXPECTED::$fs_type"
    fi
    
    # Check user setup
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           amoon@"$ip" "whoami" >/dev/null 2>&1; then
        emit_success "USER_VERIFICATION::amoon"
    else
        emit_error "USER_VERIFICATION_FAILED"
    fi
    
    # Check SSH key generation
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           amoon@"$ip" "test -f ~/.ssh/id_ed25519.pub"; then
        emit_success "SSH_KEY_VERIFICATION"
    else
        emit_warning "SSH_KEY_NOT_FOUND"
    fi
    
    # Profile-specific verification
    case "$profile" in
        "workstation")
            verify_workstation "$ip"
            ;;
        "server")
            verify_server "$ip"
            ;;
        "vm")
            verify_vm "$ip"
            ;;
    esac
    
    emit_success "VERIFICATION_COMPLETE::$profile"
}

# Profile-specific verification functions
verify_workstation() {
    local ip="$1"
    
    # Check desktop environment
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           amoon@"$ip" "systemctl is-active display-manager" >/dev/null 2>&1; then
        emit_success "DESKTOP_ENVIRONMENT_ACTIVE"
    else
        emit_warning "DESKTOP_ENVIRONMENT_INACTIVE"
    fi
    
    # Check development directories
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           amoon@"$ip" "test -d ~/Development && test -d ~/Projects"; then
        emit_success "WORKSTATION_DIRECTORIES_CREATED"
    else
        emit_warning "WORKSTATION_DIRECTORIES_MISSING"
    fi
}

verify_server() {
    local ip="$1"
    
    # Check headless operation
    if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
             amoon@"$ip" "systemctl is-active display-manager" >/dev/null 2>&1; then
        emit_success "HEADLESS_OPERATION_VERIFIED"
    else
        emit_warning "UNEXPECTED_DESKTOP_ENVIRONMENT"
    fi
    
    # Check security services
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           amoon@"$ip" "systemctl is-active fail2ban" >/dev/null 2>&1; then
        emit_success "SECURITY_SERVICES_ACTIVE"
    else
        emit_warning "SECURITY_SERVICES_INACTIVE"
    fi
}

verify_vm() {
    local ip="$1"
    
    # Check QEMU guest agent
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
           amoon@"$ip" "systemctl is-active qemu-guest-agent" >/dev/null 2>&1; then
        emit_success "QEMU_GUEST_AGENT_ACTIVE"
    else
        emit_warning "QEMU_GUEST_AGENT_INACTIVE"
    fi
}

# Main execution
main() {
    local profile="${1:-}"
    
    if [[ -z "$profile" ]]; then
        echo "Usage: $0 <profile>"
        echo "Profiles: vm, workstation, server"
        exit 1
    fi
    
    case "$profile" in
        vm|workstation|server)
            test_profile_installation "$profile"
            ;;
        *)
            error "Unknown profile: $profile"
            ;;
    esac
}

main "$@"