#!/usr/bin/env bash
# Test validation script - checks syntax without running tests

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "NixOS Test Configuration Validator"
echo "=================================="
echo

# Find nix binary
NIX_BIN=$(find /nix/store -name "nix" -type f -executable 2>/dev/null | grep -E 'bin/nix$' | head -1)
NIX_INSTANTIATE=$(find /nix/store -name "nix-instantiate" -type f -executable 2>/dev/null | grep -E 'bin/nix-instantiate$' | head -1)

if [ -z "$NIX_BIN" ] || [ -z "$NIX_INSTANTIATE" ]; then
    echo -e "${RED}Error: Nix not found in store${NC}"
    exit 1
fi

echo -e "${GREEN}Found nix at: $NIX_BIN${NC}"
echo

# Validate test files
echo "Validating test files..."
echo

ERRORS=0

# Check integration tests
echo -n "Checking integration-tests.nix... "
if $NIX_INSTANTIATE --parse tests/integration-tests.nix >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    $NIX_INSTANTIATE --parse tests/integration-tests.nix 2>&1 | head -10
    ERRORS=$((ERRORS + 1))
fi

# Check deployment tests
echo -n "Checking deployment-tests.nix... "
if $NIX_INSTANTIATE --parse tests/deployment-tests.nix >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    $NIX_INSTANTIATE --parse tests/deployment-tests.nix 2>&1 | head -10
    ERRORS=$((ERRORS + 1))
fi

# Check test filesystem module
echo -n "Checking test-filesystem.nix... "
if $NIX_INSTANTIATE --parse test-filesystem.nix >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
    $NIX_INSTANTIATE --parse test-filesystem.nix 2>&1 | head -10
    ERRORS=$((ERRORS + 1))
fi

echo
echo "Test Summary"
echo "============"

# List available tests from the files
echo
echo "Available tests in integration-tests.nix:"
grep -E "^\s*[a-zA-Z-]+-[a-zA-Z-]+ = makeTest" tests/integration-tests.nix | \
    sed 's/.*\([a-zA-Z-]*-[a-zA-Z-]*\) = makeTest.*/  - \1/' || true

echo
echo "Available tests in deployment-tests.nix:"
grep -E "^\s*[a-zA-Z-]+-[a-zA-Z-]+ = makeDeploymentTest" tests/deployment-tests.nix | \
    sed 's/.*\([a-zA-Z-]*-[a-zA-Z-]*\) = makeDeploymentTest.*/  - \1/' || true

echo
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All test files validated successfully!${NC}"
    echo
    echo "To run tests when nix is available in PATH:"
    echo "  ./tests/run-tests.sh"
    echo "  nix flake check"
else
    echo -e "${RED}Found $ERRORS errors in test files${NC}"
    exit 1
fi