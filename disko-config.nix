# Disko configuration for automatic disk detection and Btrfs setup
# This configuration will be imported by NixOS modules
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Robust disk detection using /dev/disk/by-id for stable device naming
        # Falls back to /dev path detection if by-id is not available
        device = 
          let
            # Try to find disks by stable ID first (best practice)
            diskByIdPath = "/dev/disk/by-id";
            diskIds = if builtins.pathExists diskByIdPath 
              then builtins.attrNames (builtins.readDir diskByIdPath)
              else [];
            
            # Filter for main disks (not partitions) by common patterns
            isMainDisk = id: 
              (builtins.match ".*(nvme|ata|scsi|virtio|usb).*" id != null) &&
              (builtins.match ".*-part[0-9]+.*" id == null);
            
            mainDisks = builtins.filter isMainDisk diskIds;
            
            # Fallback device paths if by-id detection fails
            fallbackDevices = [
              "/dev/vda"      # QEMU/KVM virtual disk (most common)
              "/dev/sda"      # SATA/SCSI disk  
              "/dev/nvme0n1"  # NVMe disk
              "/dev/xvda"     # Xen virtual disk
              "/dev/hda"      # IDE disk (legacy)
            ];
            
            availableFallbacks = builtins.filter builtins.pathExists fallbackDevices;
          in
            if mainDisks != [] 
            then "/dev/disk/by-id/${builtins.head mainDisks}"
            else if availableFallbacks != []
            then builtins.head availableFallbacks
            else builtins.abort "No suitable disk found for installation";
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