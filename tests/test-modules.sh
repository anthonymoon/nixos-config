#!/usr/bin/env bash
# Module-specific integration tests
# Tests individual modules and their functionality

set -euo pipefail

TEST_VM_IP="${TEST_VM_IP:-10.10.10.180}"
TEST_VM_USER="${TEST_VM_USER:-nixos}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

vm_exec() {
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$TEST_VM_USER@$TEST_VM_IP" "$@"
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

test_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

test_start() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# Test Gaming Module
test_gaming_module() {
    test_start "Gaming module functionality"
    
    # Check if Steam is available
    if vm_exec "command -v steam" >/dev/null 2>&1; then
        test_pass "Steam is installed"
    else
        test_skip "Steam not installed (gaming module disabled)"
        return
    fi
    
    # Check GameMode
    if vm_exec "command -v gamemoderun" >/dev/null 2>&1; then
        test_pass "GameMode is available"
    else
        test_fail "GameMode not found"
    fi
    
    # Check Lutris
    if vm_exec "command -v lutris" >/dev/null 2>&1; then
        test_pass "Lutris is installed"
    else
        test_fail "Lutris not found"
    fi
    
    # Check Wine
    if vm_exec "command -v wine" >/dev/null 2>&1; then
        test_pass "Wine is installed"
    else
        test_fail "Wine not found"
    fi
    
    # Test low-latency audio configuration
    if vm_exec "systemctl --user is-active pipewire" >/dev/null 2>&1; then
        test_pass "PipeWire is running"
    else
        test_fail "PipeWire not active"
    fi
}

# Test Development Module
test_development_module() {
    test_start "Development module functionality"
    
    # Check programming languages
    local languages=("node" "python3" "rustc" "go")
    for lang in "${languages[@]}"; do
        if vm_exec "command -v $lang" >/dev/null 2>&1; then
            test_pass "$lang is installed"
        else
            test_skip "$lang not found (development module may be disabled)"
        fi
    done
    
    # Check development tools
    local tools=("git" "docker" "code")
    for tool in "${tools[@]}"; do
        if vm_exec "command -v $tool" >/dev/null 2>&1; then
            test_pass "$tool is available"
        else
            test_skip "$tool not found"
        fi
    done
    
    # Test PostgreSQL service
    if vm_exec "systemctl is-active postgresql" >/dev/null 2>&1; then
        test_pass "PostgreSQL service is active"
        
        # Test database connectivity
        if vm_exec "sudo -u postgres psql -c 'SELECT version();'" >/dev/null 2>&1; then
            test_pass "PostgreSQL is responsive"
        else
            test_fail "PostgreSQL not responsive"
        fi
    else
        test_skip "PostgreSQL not active (development module may be disabled)"
    fi
    
    # Test Redis service
    if vm_exec "systemctl is-active redis-development" >/dev/null 2>&1; then
        test_pass "Redis service is active"
    else
        test_skip "Redis not active"
    fi
    
    # Test Docker service
    if vm_exec "systemctl is-active docker" >/dev/null 2>&1; then
        test_pass "Docker service is active"
        
        # Test Docker functionality
        if vm_exec "docker run --rm hello-world" >/dev/null 2>&1; then
            test_pass "Docker can run containers"
        else
            test_fail "Docker cannot run containers"
        fi
    else
        test_skip "Docker not active"
    fi
}

# Test Media Server Module
test_media_server_module() {
    test_start "Media server module functionality"
    
    # Check if media server services are available
    local services=("radarr" "sonarr" "lidarr" "jackett" "jellyfin")
    local found_services=0
    
    for service in "${services[@]}"; do
        if vm_exec "systemctl is-active $service" >/dev/null 2>&1; then
            test_pass "$service service is active"
            found_services=$((found_services + 1))
        else
            test_skip "$service not active"
        fi
    done
    
    if [[ $found_services -eq 0 ]]; then
        test_skip "Media server module appears to be disabled"
        return
    fi
    
    # Test qBittorrent
    if vm_exec "systemctl is-active qbittorrent" >/dev/null 2>&1; then
        test_pass "qBittorrent service is active"
    else
        test_skip "qBittorrent not active"
    fi
    
    # Test Samba shares
    if vm_exec "systemctl is-active smbd" >/dev/null 2>&1; then
        test_pass "Samba service is active"
        
        # Test Samba configuration
        if vm_exec "testparm -s" >/dev/null 2>&1; then
            test_pass "Samba configuration is valid"
        else
            test_fail "Samba configuration invalid"
        fi
    else
        test_skip "Samba not active"
    fi
    
    # Test storage directories
    if vm_exec "test -d /storage/media && test -d /storage/downloads" >/dev/null 2>&1; then
        test_pass "Storage directories exist"
    else
        test_skip "Storage directories not found"
    fi
}

# Test Security Module
test_security_module() {
    test_start "Security module functionality"
    
    # Test Fail2ban
    if vm_exec "systemctl is-active fail2ban" >/dev/null 2>&1; then
        test_pass "Fail2ban service is active"
        
        # Test Fail2ban configuration
        if vm_exec "sudo fail2ban-client status" >/dev/null 2>&1; then
            test_pass "Fail2ban is functional"
        else
            test_fail "Fail2ban not responding"
        fi
    else
        test_skip "Fail2ban not active (security module may be disabled)"
    fi
    
    # Test AppArmor
    if vm_exec "systemctl is-active apparmor" >/dev/null 2>&1; then
        test_pass "AppArmor service is active"
    else
        test_skip "AppArmor not active"
    fi
    
    # Test firewall rules
    if vm_exec "sudo iptables -L" >/dev/null 2>&1; then
        test_pass "Firewall rules are accessible"
        
        # Check for custom rules
        if vm_exec "sudo iptables -L | grep -q 'recent'" >/dev/null 2>&1; then
            test_pass "Rate limiting rules detected"
        else
            test_skip "No rate limiting rules found"
        fi
    else
        test_fail "Cannot access firewall rules"
    fi
    
    # Test SSH hardening
    if vm_exec "sudo sshd -T | grep -q 'passwordauthentication no'" >/dev/null 2>&1; then
        test_pass "SSH password authentication disabled"
    else
        test_fail "SSH password authentication not disabled"
    fi
    
    # Test kernel security parameters
    local sysctl_checks=(
        "net.ipv4.conf.all.rp_filter=1"
        "net.ipv4.tcp_syncookies=1"
        "kernel.dmesg_restrict=1"
    )
    
    for check in "${sysctl_checks[@]}"; do
        local param="${check%=*}"
        local expected="${check#*=}"
        local actual
        actual=$(vm_exec "sysctl -n $param" 2>/dev/null || echo "")
        
        if [[ "$actual" == "$expected" ]]; then
            test_pass "Kernel parameter $param correctly set"
        else
            test_skip "Kernel parameter $param not set (expected: $expected, got: $actual)"
        fi
    done
}

# Test System Integration
test_system_integration() {
    test_start "System integration tests"
    
    # Test user groups
    local expected_groups=("wheel" "networkmanager")
    for group in "${expected_groups[@]}"; do
        if vm_exec "groups amoon | grep -q $group" >/dev/null 2>&1; then
            test_pass "User amoon is in $group group"
        else
            test_fail "User amoon not in $group group"
        fi
    done
    
    # Test sudo configuration
    if vm_exec "sudo -n echo 'sudo works'" >/dev/null 2>&1; then
        test_pass "Passwordless sudo is working"
    else
        test_fail "Passwordless sudo not configured"
    fi
    
    # Test network configuration
    if vm_exec "systemctl is-active NetworkManager" >/dev/null 2>&1; then
        test_pass "NetworkManager is active"
    else
        test_skip "NetworkManager not active"
    fi
    
    # Test time synchronization
    if vm_exec "timedatectl status | grep -q 'NTP service: active'" >/dev/null 2>&1; then
        test_pass "NTP synchronization is active"
    else
        test_skip "NTP synchronization not active"
    fi
    
    # Test filesystem (now using Btrfs with Disko)
    local fs_type
    fs_type=$(vm_exec "stat -f / --format='%T'" 2>/dev/null || echo "unknown")
    if [[ "$fs_type" == "btrfs" ]]; then
        test_pass "Root filesystem is Btrfs"
    elif [[ "$fs_type" == "xfs" ]]; then
        test_pass "Root filesystem is XFS (legacy)"
    else
        test_info "Root filesystem type: $fs_type"
    fi
    
    # Test EFI boot
    if vm_exec "test -d /sys/firmware/efi" >/dev/null 2>&1; then
        test_pass "System booted with EFI"
    else
        test_fail "System not booted with EFI"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Module Integration Tests${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""
    
    local module="${1:-all}"
    
    case "$module" in
        "gaming")
            test_gaming_module
            ;;
        "development")
            test_development_module
            ;;
        "media-server")
            test_media_server_module
            ;;
        "security")
            test_security_module
            ;;
        "system")
            test_system_integration
            ;;
        "all")
            test_gaming_module
            echo ""
            test_development_module
            echo ""
            test_media_server_module
            echo ""
            test_security_module
            echo ""
            test_system_integration
            ;;
        *)
            echo "Usage: $0 [module]"
            echo ""
            echo "Available modules:"
            echo "  gaming       - Test gaming module functionality"
            echo "  development  - Test development module functionality"
            echo "  media-server - Test media server module functionality"
            echo "  security     - Test security module functionality"
            echo "  system       - Test system integration"
            echo "  all          - Run all module tests"
            exit 1
            ;;
    esac
}

main "$@"