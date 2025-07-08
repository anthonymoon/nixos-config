# Disko configuration for automatic disk detection and BTRFS setup
# This configuration will be imported by NixOS modules
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Use a script to auto-detect the primary disk at runtime
        # This will be the first available disk that's not a CD-ROM
        device = builtins.head (
          builtins.filter (dev: builtins.pathExists dev) [
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
            # EFI System Partition for UEFI boot
            boot = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" "umask=0077" ];
              };
            };

            # The main BTRFS partition for the system.
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/";
                # BTRFS mount options optimized for modern systems
                mountOptions = [
                  "defaults"
                  "compress=zstd"  # Enable transparent compression
                  "noatime"        # Reduce writes by not updating file access times
                  "nodiratime"     # Don't update directory access times
                ];
              };
            };
          };
        };
      };
    };
  };
}