#!/usr/bin/env bash
# Internal Stream Runner - Monitored by Agent
# This script is called by the agent monitor for self-healing capabilities

set -euo pipefail

IP="$1"
PROFILE="$2"
LOG_FILE="$3"

# Simply execute the SSH monitoring with structured output
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "nixos@$IP" \
    "script -q -c 'sudo bash /tmp/monitored_installer.sh $PROFILE' /tmp/monitored_install.log && cat /tmp/monitored_install.log"