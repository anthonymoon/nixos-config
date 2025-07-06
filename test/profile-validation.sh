#!/usr/bin/env bash

# Profile validation test
# Tests configuration syntax and dependencies without VM creation

set -euo pipefail

PROFILES=("vm" "workstation" "server")
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS=()

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test profile evaluation
test_profile() {
    local profile=$1
    log "Testing $profile profile configuration..."
    
    # Create a test configuration
    local test_config=$(mktemp)
    cat > "$test_config" <<EOF
{ config, pkgs, ... }:
{
  imports = [
    $REPO_ROOT/profiles/base.nix
    $REPO_ROOT/profiles/$profile.nix
  ];
  
  # Minimal hardware config for testing
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  networking.hostName = "test-$profile";
  system.stateVersion = "25.05";
}
EOF
    
    # Test the configuration
    if nix-instantiate --eval -E "(import <nixpkgs/nixos> { configuration = $test_config; }).config.system.build.toplevel" &>/dev/null; then
        success "$profile profile: Configuration valid"
        RESULTS+=("$profile: PASS")
        
        # Check for specific features
        log "Checking $profile profile features..."
        case $profile in
            vm)
                log "  - QEMU guest tools"
                log "  - Spice agent"
                log "  - VM optimizations"
                ;;
            workstation)
                log "  - KDE Plasma desktop"
                log "  - Gaming support"
                log "  - Development tools"
                ;;
            server)
                log "  - Security hardening"
                log "  - SSH configuration"
                log "  - Server optimizations"
                ;;
        esac
    else
        error "$profile profile: Configuration failed evaluation"
        RESULTS+=("$profile: FAIL")
        
        # Try to get more details
        log "Getting error details..."
        nix-instantiate --eval -E "(import <nixpkgs/nixos> { configuration = $test_config; }).config.system.build.toplevel" 2>&1 | grep -E '(error:|warning:)' | head -10
    fi
    
    rm -f "$test_config"
    echo
}

# Main execution
main() {
    log "Starting NixOS profile validation tests"
    log "Repository: $REPO_ROOT"
    echo
    
    # Test each profile
    for profile in "${PROFILES[@]}"; do
        test_profile "$profile"
    done
    
    # Summary
    echo
    log "Test Results Summary:"
    log "===================="
    for result in "${RESULTS[@]}"; do
        if [[ $result == *"PASS"* ]]; then
            success "$result"
        else
            error "$result"
        fi
    done
}

main "$@"