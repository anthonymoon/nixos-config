#!/usr/bin/env bash
# Test runner wrapper with proper sudo configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }

# Check if running with proper permissions
check_permissions() {
    log "Checking permissions..."
    
    # Check if we can access libvirt
    if ! sudo virsh --connect qemu:///system list &>/dev/null; then
        error "Cannot access libvirt. Please ensure:"
        error "1. You have sudo access"
        error "2. libvirtd is running: sudo systemctl start libvirtd"
        error "3. You're in the libvirt group: sudo usermod -aG libvirt $USER"
        exit 1
    fi
    
    # Check KVM access
    if [[ ! -e /dev/kvm ]]; then
        error "KVM not available. Please ensure virtualization is enabled in BIOS"
        exit 1
    fi
    
    if [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; then
        warning "KVM permissions may be incorrect. Attempting to fix..."
        sudo chmod 666 /dev/kvm
    fi
    
    success "Permissions check passed"
}

# Install dependencies if needed
install_dependencies() {
    log "Checking dependencies..."
    
    local missing=()
    local deps=("virsh" "qemu-img" "nc" "ssh" "sshpass")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        warning "Missing dependencies: ${missing[*]}"
        log "Installing dependencies..."
        
        # Detect package manager
        if command -v pacman &>/dev/null; then
            # Arch Linux
            sudo pacman -S --needed --noconfirm qemu libvirt netcat openssh sshpass
        elif command -v apt-get &>/dev/null; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y qemu-system libvirt-daemon-system libvirt-clients netcat openssh-client sshpass
        elif command -v nix-env &>/dev/null; then
            # NixOS
            nix-env -iA nixpkgs.qemu nixpkgs.libvirt nixpkgs.netcat nixpkgs.openssh nixpkgs.sshpass
        else
            error "Unsupported package manager. Please install: ${missing[*]}"
            exit 1
        fi
    fi
    
    success "All dependencies installed"
}

# Clean up any existing test artifacts
cleanup_artifacts() {
    log "Cleaning up previous test artifacts..."
    
    # Stop and remove any existing test VMs
    for vm in $(sudo virsh list --all --name | grep nixos-test); do
        log "Removing VM: $vm"
        sudo virsh destroy "$vm" 2>/dev/null || true
        sudo virsh undefine "$vm" --remove-all-storage 2>/dev/null || true
    done
    
    # Clean up disk images
    sudo rm -f /var/lib/libvirt/images/nixos-test-*.qcow2
    
    # Clean up logs and state
    rm -rf /tmp/nixos-test-*
    
    success "Cleanup complete"
}

# Run the actual tests
run_tests() {
    local test_type="${1:-streaming}"
    local profile="${2:-all}"
    
    log "Starting $test_type tests for profile: $profile"
    
    case "$test_type" in
        basic)
            # Use basic VM test framework
            log "Running basic VM test framework..."
            "$SCRIPT_DIR/vm-test-framework.sh" test "$profile"
            ;;
        streaming)
            # Use streaming test runner
            log "Running streaming test runner..."
            # Update virsh commands to use sudo
            sed -i 's/virsh --connect/sudo virsh --connect/g' "$SCRIPT_DIR/streaming-test-runner.sh" 2>/dev/null || \
            sed -i '' 's/virsh --connect/sudo virsh --connect/g' "$SCRIPT_DIR/streaming-test-runner.sh" 2>/dev/null || true
            
            "$SCRIPT_DIR/streaming-test-runner.sh" test "$profile"
            ;;
        agent)
            # Use Python agent monitor
            log "Running Python agent monitor..."
            if ! command -v python3 &>/dev/null; then
                error "Python 3 is required for agent testing"
                exit 1
            fi
            
            # Check Python dependencies
            if ! python3 -c "import asyncssh" 2>/dev/null; then
                log "Installing Python dependencies..."
                pip3 install --user asyncssh
            fi
            
            # Update Python script to use sudo
            sudo -E python3 "$SCRIPT_DIR/agent-monitor.py"
            ;;
        *)
            error "Unknown test type: $test_type"
            echo "Usage: $0 [basic|streaming|agent] [vm|workstation|server|all]"
            exit 1
            ;;
    esac
}

# Generate test report
generate_report() {
    log "Generating test report..."
    
    local report_file="/tmp/nixos-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "NixOS Configuration Test Report"
        echo "==============================="
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo ""
        
        if [[ -f /tmp/nixos-test-state.json ]]; then
            echo "Test Results:"
            echo "-------------"
            cat /tmp/nixos-test-state.json | jq -r 'to_entries | .[] | "\(.key): \(.value.status // "unknown")"'
            echo ""
        fi
        
        if [[ -d /tmp/nixos-test-logs ]]; then
            echo "Log Files:"
            echo "----------"
            ls -la /tmp/nixos-test-logs/
            echo ""
            
            echo "Recent Errors:"
            echo "--------------"
            grep -i error /tmp/nixos-test-logs/*.log 2>/dev/null | tail -20 || echo "No errors found"
        fi
    } | tee "$report_file"
    
    success "Report saved to: $report_file"
}

# Main execution
main() {
    log "NixOS Automated Testing Framework"
    log "================================="
    
    # Parse arguments
    local test_type="${1:-streaming}"
    local profile="${2:-all}"
    
    # Run checks
    check_permissions
    install_dependencies
    
    # Clean up if requested
    if [[ "$test_type" == "clean" ]]; then
        cleanup_artifacts
        exit 0
    fi
    
    # Run tests
    log "Starting tests..."
    if run_tests "$test_type" "$profile"; then
        success "All tests completed successfully!"
        generate_report
        exit 0
    else
        error "Some tests failed!"
        generate_report
        exit 1
    fi
}

# Run main
main "$@"