# Disko configuration for automatic disk detection and Btrfs setup
# This configuration will be imported by NixOS modules
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Use a simple heuristic for the first available disk
        # This will be the first /dev/vda, /dev/sda, /dev/nvme0n1, etc.
        device = builtins.head (
          builtins.filter (disk: builtins.pathExists disk) [
            "/dev/vda"      # QEMU/KVM virtual disk (most common)
            "/dev/sda"      # SATA/SCSI disk
            "/dev/nvme0n1"  # NVMe disk
            "/dev/xvda"     # Xen virtual disk
            "/dev/hda"      # IDE disk (legacy)
          ]
        );
        content = {
          type = "gpt";
          partitions = {
            # Partition for the bootloader (UEFI).
            boot = {
              size = "1G";
              type = "EF00"; # EFI System Partition type
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };

            # The main Btrfs partition for the system.
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                # Global mount options for the entire Btrfs filesystem.
                # Optimized for modern SSDs and virtual disks.
                mountOptions = [
                  "compress=zstd" # Use Zstandard compression globally
                  "ssd"           # Indicate it's a Solid State Drive (safe for most modern VMs)
                  "discard=async" # Enable asynchronous TRIM for better performance
                  "noatime"       # Reduce writes by not updating file access times
                ];
                subvolumes = {
                  # Subvolume for the root filesystem.
                  "@" = { mountpoint = "/"; };

                  # Subvolume for home directories.
                  "@home" = { mountpoint = "/home"; };

                  # Subvolume for the Nix store.
                  "@nix" = { mountpoint = "/nix"; };

                  # Subvolume for logs.
                  "@log" = { mountpoint = "/var/log"; };

                  # A dedicated subvolume for snapshots.
                  "@snapshots" = {};
                };
              };
            };
          };
        };
      };
    };
  };
}