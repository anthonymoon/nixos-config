#!/usr/bin/env bash
set -euo pipefail

echo "🔨 Building custom NixOS ISO with SSH access..."
echo "================================================"

# Change to the iso directory
cd "$(dirname "$0")/iso"

# Build the ISO
echo "📦 Starting build process..."
nix build . --extra-experimental-features "nix-command flakes"

# Check if build succeeded
if [ -d "result" ]; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "📍 ISO location:"
    ls -la result/iso/*.iso
    echo ""
    echo "📋 To use the ISO:"
    echo "  - Copy to USB: sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress"
    echo "  - Boot VM: qemu-system-x86_64 -enable-kvm -m 2048 -cdrom result/iso/*.iso"
    echo ""
    echo "🔑 SSH access:"
    echo "  - Root user has your SSH key pre-installed"
    echo "  - Default passwords: root='nixos', nixos='nixos'"
else
    echo "❌ Build failed!"
    exit 1
fi