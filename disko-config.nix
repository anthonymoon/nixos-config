{ lib, ... }:

let
  # --- Auto-detection logic for the main disk ---
  # It now searches for the first available NVMe, ATA, SCSI, or Virtio disk.
  # This makes the configuration portable across physical and virtual machines.
  findDisk =
    let
      # List all entries in /dev/disk/by-id
      diskIds = builtins.attrNames (builtins.readDir "/dev/disk/by-id");
      # Filter for common disk types, excluding partitions
      isMainDisk = id:
        (
          lib.strings.startsWith "nvme-eui." id ||
          lib.strings.startsWith "nvme-Samsung_SSD" id ||
          lib.strings.startsWith "ata-" id ||
          lib.strings.startsWith "virtio-" id || # Added for QEMU/KVM virtual disks
          lib.strings.startsWith "scsi-" id      # Added for broader virtual/enterprise disk compatibility
        ) && !(lib.strings.hasInfix "-part" id);
      # Find the first disk that matches our criteria
      diskId = lib.findFirst isMainDisk null diskIds;
    in
    # If a disk is found, return its full path, otherwise abort.
    if diskId != null
    then "/dev/disk/by-id/${diskId}"
    else builtins.abort "No suitable NVMe, ATA, SCSI, or Virtio disk found in /dev/disk/by-id";
in
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = findDisk; # Use the auto-detected disk path
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