_: {
  # Enable ZRAM with half system memory
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  # This formats the disk with the ext4 filesystem
  # Other examples found here: https://github.com/nix-community/disko/tree/master/example
  disko.devices = {
    disk = {
      main = {
        device = "/dev/%DISK%";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1G";
              label = "EFI";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ 
                  "defaults"
                  "umask=0077"      # Only root can access
                  "fmask=0077"      # File permissions
                  "dmask=0077"      # Directory permissions
                  "iocharset=utf8"  # UTF-8 character encoding
                  "codepage=437"    # DOS codepage
                  "shortname=mixed" # Allow mixed case
                  "errors=remount-ro" # Remount read-only on errors
                ];
              };
            };
            root = {
              size = "100%";
              label = "ROOT";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
                mountOptions = [ 
                  "defaults"
                  "noatime"         # Don't update access times
                  "nodiratime"      # Don't update directory access times
                  "discard"         # Enable TRIM for SSDs
                  "inode64"         # Use 64-bit inodes
                  "allocsize=64m"   # Preallocate in 64MB chunks for performance
                  "logbufs=8"       # Increase log buffers for better performance
                  "logbsize=256k"   # Larger log buffer size
                  "attr2"           # Better extended attribute performance
                  "largeio"         # Allow large I/O operations
                  "swalloc"         # Stripe-width allocation for RAID/SSDs
                ];
              };
            };
          };
        };
      };
    };
  };
  
  # Use partition labels for mounting instead of device paths
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
    options = [ 
      "defaults"
      "umask=0077"      # Only root can access
      "fmask=0077"      # File permissions
      "dmask=0077"      # Directory permissions
      "iocharset=utf8"  # UTF-8 character encoding
      "codepage=437"    # DOS codepage
      "shortname=mixed" # Allow mixed case
      "errors=remount-ro" # Remount read-only on errors
      "noatime"         # Don't update access times (reduces wear)
    ];
  };
  
  fileSystems."/" = {
    device = "/dev/disk/by-label/ROOT";
    fsType = "xfs";
    options = [ 
      "defaults"
      "noatime"         # Don't update access times
      "nodiratime"      # Don't update directory access times
      "discard"         # Enable TRIM for SSDs
      "inode64"         # Use 64-bit inodes
      "allocsize=64m"   # Preallocate in 64MB chunks for performance
      "logbufs=8"       # Increase log buffers for better performance
      "logbsize=256k"   # Larger log buffer size
      "attr2"           # Better extended attribute performance
      "largeio"         # Allow large I/O operations
      "swalloc"         # Stripe-width allocation for RAID/SSDs
    ];
  };
}