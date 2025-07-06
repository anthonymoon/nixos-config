#!/usr/bin/env bash

# SSH helper for testing - disables host key checking
# Usage: ./ssh-test.sh <ip> [command]

IP="${1:-10.10.10.180}"
shift
CMD="${@:-nixos-version}"

SSH_OPTS=(
    -o "StrictHostKeyChecking=no"
    -o "UserKnownHostsFile=/dev/null"
    -o "LogLevel=ERROR"
    -o "ConnectTimeout=5"
)

echo "Connecting to amoon@${IP}..."
ssh "${SSH_OPTS[@]}" amoon@"${IP}" "$CMD"