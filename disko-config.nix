# Disko configuration for automatic disk detection and XFS setup
# This configuration will be imported by NixOS modules
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Auto-detect the primary disk at runtime
        # Disko will handle device detection during installation
        device = "/dev/disk/by-id/AUTO"; # Placeholder - disko auto-detects
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

            # Main system partition using XFS
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                  "noatime"      # Reduce writes by not updating file access times
                  "nodiratime"   # Don't update directory access times
                ];
              };
            };
          };
        };
      };
    };
  };
}