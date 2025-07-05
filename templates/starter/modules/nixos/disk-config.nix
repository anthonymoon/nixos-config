_: {
  # Enable ZRAM with half system memory
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  
  # Enable periodic TRIM for SSDs (better than continuous discard)
  services.fstrim = {
    enable = true;
    interval = "weekly"; # Run fstrim once a week
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
                  "noatime"         # Don't update access times (reduces wear)
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
                  "relatime"        # Default in modern kernels, better than noatime
                  "inode64"         # Use 64-bit inodes for scalability
                  "logbufs=8"       # Increase log buffers for better performance
                  "logbsize=256k"   # Larger log buffer size for heavy modifications
                  "attr2"           # Better extended attribute performance (default in XFS v5)
                  "largeio"         # Allow large I/O operations
                  "swalloc"         # Stripe-width allocation optimization for SSDs
                  # Note: 'discard' is not recommended - use fstrim instead for better performance
                  # Note: 'nobarrier' removed in kernel 4.19+ - barriers handled automatically
                ];
              };
            };
          };
        };
      };
    };
  };
  
  # Disko handles all filesystem definitions automatically
  # No manual fileSystems configuration needed - disko creates them from the partition definitions above
}