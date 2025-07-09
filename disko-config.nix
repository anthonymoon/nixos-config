# Disko configuration for BTRFS setup with proper boot support
# This configuration will be imported by NixOS modules
{
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition for UEFI boot
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            # The main BTRFS partition for the system
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Force creation, useful for re-running disko
                subvolumes = {
                  # Subvolume for the root filesystem
                  "/rootfs" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };

                  # Subvolume for home directories
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };

                  # Subvolume for the Nix store
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };

                  # Subvolume for logs
                  "/var/log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" ];
                  };

                  # A dedicated subvolume for snapshots
                  "/snapshots" = {
                    mountpoint = "/.snapshots";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}