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
                type = "btrfs";
                extraArgs = [ "-f" ]; # Force creation, useful for re-running disko
                subvolumes = {
                  # Subvolume for the root filesystem.
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ "compress=zstd" "noatime" "nodiratime" ];
                  };

                  # Subvolume for home directories.
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [ "compress=zstd" "noatime" "nodiratime" ];
                  };

                  # Subvolume for the Nix store.
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [ "compress=zstd" "noatime" "nodiratime" ];
                  };

                  # Subvolume for logs.
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [ "compress=zstd" "noatime" "nodiratime" ];
                  };

                  # A dedicated subvolume for snapshots.
                  "@snapshots" = {
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