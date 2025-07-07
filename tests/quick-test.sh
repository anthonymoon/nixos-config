#!/usr/bin/env bash
# Quick test runner for NixOS configuration tests
# This bypasses flake issues and runs tests directly

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "NixOS Configuration Quick Test Runner"
echo "===================================="
echo

# Available tests
TESTS=(
    "vm-profile:Basic VM configuration test"
    "server-profile:Server hardening and SSH test"
)

# If no argument, show menu
if [ $# -eq 0 ]; then
    echo "Available tests:"
    for i in "${!TESTS[@]}"; do
        IFS=':' read -r name desc <<< "${TESTS[$i]}"
        echo "  $((i+1))) $name - $desc"
    done
    echo
    read -p "Select test (1-${#TESTS[@]}): " choice
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#TESTS[@]}" ]; then
        TEST_NAME=$(echo "${TESTS[$((choice-1))]}" | cut -d: -f1)
    else
        echo -e "${RED}Invalid selection${NC}"
        exit 1
    fi
else
    TEST_NAME="$1"
fi

# Run the test
echo
echo -e "${BLUE}Running test: $TEST_NAME${NC}"
echo

if nix-build standalone-test.nix -A "$TEST_NAME"; then
    echo
    echo -e "${GREEN}✓ Test passed: $TEST_NAME${NC}"
else
    echo
    echo -e "${RED}✗ Test failed: $TEST_NAME${NC}"
    exit 1
fi