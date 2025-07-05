#!/usr/bin/env bash
# Local testing script for NixOS configuration validation
# Run this before pushing changes to ensure they'll pass CI

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_VM_MEMORY=${TEST_VM_MEMORY:-4096}
SKIP_VM_TESTS=${SKIP_VM_TESTS:-false}

# Change to project directory
cd "$PROJECT_DIR"

log_info "Starting local NixOS configuration validation..."
log_info "Project directory: $PROJECT_DIR"

# Test 1: Syntax and Evaluation Check
log_info "Running syntax and evaluation checks..."
if nix flake check --show-trace; then
    log_success "Flake syntax and evaluation check passed"
else
    log_error "Flake syntax or evaluation failed"
    exit 1
fi

# Test 2: Build Validation
log_info "Testing configuration build..."
if nix build .#nixosConfigurations.x86_64-linux.config.system.build.toplevel --dry-run --show-trace; then
    log_success "Configuration build validation passed"
else
    log_error "Configuration build validation failed"
    exit 1
fi

# Test 3: Package Availability Check
log_info "Validating package availability..."
if nix build .#nixosConfigurations.x86_64-linux.config.environment.systemPackages --dry-run --show-trace; then
    log_success "All packages are available"
else
    log_error "Some packages are not available"
    exit 1
fi

# Test 4: Code Quality Checks
log_info "Running code quality checks..."

# Check if nixfmt is available
if command -v nixfmt >/dev/null 2>&1; then
    log_info "Checking Nix code formatting..."
    if find . -name "*.nix" -exec nixfmt --check {} \; 2>/dev/null; then
        log_success "Code formatting check passed"
    else
        log_warning "Code formatting issues found. Run 'nixfmt **/*.nix' to fix"
    fi
else
    log_warning "nixfmt not available, skipping formatting check"
fi

# Check if statix is available
if command -v statix >/dev/null 2>&1; then
    log_info "Running static analysis..."
    if statix check . --ignore target; then
        log_success "Static analysis passed"
    else
        log_warning "Static analysis found issues"
    fi
else
    log_warning "statix not available, skipping static analysis"
fi

# Check if deadnix is available
if command -v deadnix >/dev/null 2>&1; then
    log_info "Checking for dead code..."
    if deadnix --check .; then
        log_success "No dead code found"
    else
        log_warning "Dead code detected"
    fi
else
    log_warning "deadnix not available, skipping dead code check"
fi

# Test 5: Security Validation
log_info "Running security validation..."

# Check for insecure packages
log_info "Checking for insecure packages..."
if nix eval .#nixosConfigurations.x86_64-linux.config.nixpkgs.config.permittedInsecurePackages --json >/dev/null 2>&1; then
    INSECURE_PACKAGES=$(nix eval .#nixosConfigurations.x86_64-linux.config.nixpkgs.config.permittedInsecurePackages --json 2>/dev/null || echo "[]")
    if [ "$INSECURE_PACKAGES" = "[]" ] || [ "$INSECURE_PACKAGES" = "null" ]; then
        log_success "No insecure packages permitted"
    else
        log_warning "Insecure packages are permitted: $INSECURE_PACKAGES"
    fi
else
    log_success "No insecure packages configuration found"
fi

# Check SSH configuration
log_info "Validating SSH configuration..."
SSH_CONFIG=$(nix eval .#nixosConfigurations.x86_64-linux.config.services.openssh.settings --json 2>/dev/null || echo "{}")
if echo "$SSH_CONFIG" | jq -e '.PasswordAuthentication' >/dev/null 2>&1; then
    PASSWORD_AUTH=$(echo "$SSH_CONFIG" | jq -r '.PasswordAuthentication')
    ROOT_LOGIN=$(echo "$SSH_CONFIG" | jq -r '.PermitRootLogin')
    log_info "SSH PasswordAuthentication: $PASSWORD_AUTH"
    log_info "SSH PermitRootLogin: $ROOT_LOGIN"
fi

# Test 6: VM Integration Tests (optional)
if [ "$SKIP_VM_TESTS" = "false" ]; then
    log_info "Running VM integration tests..."
    
    if [ -f "tests/vm-integration.nix" ]; then
        if nix build .#checks.x86_64-linux.vm-test --show-trace; then
            log_success "VM integration tests passed"
        else
            log_error "VM integration tests failed"
            exit 1
        fi
    else
        log_warning "VM integration test file not found, skipping"
    fi
else
    log_info "Skipping VM tests (SKIP_VM_TESTS=true)"
fi

# Test 7: Generation Comparison (if current system)
if [ -d "/nix/var/nix/profiles" ]; then
    log_info "Comparing with current system generation..."
    
    CURRENT_GEN=$(readlink /nix/var/nix/profiles/system 2>/dev/null || echo "none")
    if [ "$CURRENT_GEN" != "none" ]; then
        log_info "Current generation: $(basename "$CURRENT_GEN")"
        
        # Build new configuration
        nix build .#nixosConfigurations.x86_64-linux.config.system.build.toplevel -o /tmp/nixos-test-result
        NEW_GEN="/tmp/nixos-test-result"
        
        if [ -L "$NEW_GEN" ]; then
            log_info "New configuration built successfully"
            
            # Compare package differences
            if command -v nix-diff >/dev/null 2>&1; then
                log_info "Showing package differences..."
                nix-diff "$CURRENT_GEN" "$NEW_GEN" || true
            fi
        fi
    else
        log_info "Not running on NixOS, skipping generation comparison"
    fi
fi

# Test 8: Resource Usage Estimation
log_info "Estimating resource usage..."
if nix path-info -S .#nixosConfigurations.x86_64-linux.config.system.build.toplevel 2>/dev/null; then
    log_success "Resource usage estimation completed"
else
    log_warning "Could not estimate resource usage"
fi

# Test 9: Flake Lock Validation
log_info "Validating flake.lock..."
if [ -f "flake.lock" ]; then
    # Check if flake.lock is up to date
    if nix flake update --commit-lock-file --dry-run >/dev/null 2>&1; then
        log_success "Flake lock file is valid"
    else
        log_warning "Flake lock file might need updating"
    fi
else
    log_warning "No flake.lock file found"
fi

# Test 10: Documentation Check
log_info "Checking documentation..."
if [ -f "README.md" ]; then
    log_success "README.md exists"
else
    log_warning "No README.md found"
fi

if [ -d ".github" ]; then
    log_success "GitHub configuration directory exists"
else
    log_warning "No GitHub configuration found"
fi

# Summary
log_success "Local validation completed successfully!"
log_info "Your configuration is ready for CI/CD pipeline"

echo ""
log_info "Next steps:"
echo "  1. git add ."
echo "  2. git commit -m 'Your commit message'"
echo "  3. git push origin dev  # for development deployment"
echo "  4. Create PR from staging to main for production"

# Cleanup
rm -f /tmp/nixos-test-result

exit 0