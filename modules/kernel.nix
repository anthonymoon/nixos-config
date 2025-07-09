# Universal Kernel Configuration Module
# Optimized for performance across VM, workstation, and server environments
# Supports Intel/AMD, virtio, bare metal, and modern hardware

{ config, lib, pkgs, ... }:

{
  # Latest mainline kernel for maximum performance and hardware support
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    
    # Comprehensive kernel modules for all hardware types
    initrd = {
      availableKernelModules = [
        # Storage controllers
        "xhci_pci"           # USB 3.0 controller
        "ahci"               # SATA AHCI controller
        "nvme"               # NVMe SSD support
        "nvme_core"          # NVMe core support
        "nvme_keyring"       # NVMe keyring support
        "usb_storage"        # USB storage devices
        "sd_mod"             # SCSI disk support
        "sr_mod"             # SCSI CD/DVD support
        "sg"                 # SCSI generic driver
        "rtsx_pci_sdmmc"     # Realtek card readers
        "uas"                # USB Attached SCSI
        
        # Virtio support (for VMs)
        "virtio_pci"         # Virtio PCI interface
        "virtio_blk"         # Virtio block devices
        "virtio_net"         # Virtio network
        "virtio_scsi"        # Virtio SCSI
        "virtio_rng"         # Virtio random number generator
        
        # Device mapper and storage
        "dm_mod"             # Device mapper core
        "dm_cache"           # Device mapper caching
        "dm_crypt"           # Device mapper encryption
        "dm_raid"            # Device mapper RAID
        "dm_snapshot"        # Device mapper snapshots
        "md_mod"             # MD RAID core
        
        # RAID support
        "raid0"              # RAID 0 support
        "raid1"              # RAID 1 support
        "raid10"             # RAID 10 support
        "raid456"            # RAID 4/5/6 support
        
        # Filesystems
        "btrfs"              # BTRFS filesystem
        "xfs"                # XFS filesystem
        "ext4"               # EXT4 filesystem
        "vfat"               # FAT32 (for EFI)
        "fat"                # FAT filesystem
        "exfat"              # exFAT filesystem
        "zfs"                # ZFS filesystem
        "spl"                # Solaris Porting Layer (for ZFS)
        
        # GPU and graphics
        "amdgpu"             # AMD GPU driver
        "nvidia"             # NVIDIA GPU driver
        "nvidia_drm"         # NVIDIA DRM support
        "nvidia_modeset"     # NVIDIA mode setting
        "nvidia_uvm"         # NVIDIA unified memory
        "qxl"                # QXL graphics (for VMs)
        "drm_exec"           # DRM execution context
        "drm_ttm_helper"     # DRM TTM helper
        "ttm"                # TTM memory manager
        
        # Network and I/O
        "e1000e"             # Intel Ethernet
        "r8169"              # Realtek Ethernet
        "ixgbe"              # Intel 10GbE
        "thunderbolt"        # Thunderbolt support
        "cfg80211"           # WiFi configuration
        
        # Input devices
        "atkbd"              # AT keyboard
        "i8042"              # PS/2 controller
        "serio"              # Serial I/O
        "psmouse"            # PS/2 mouse
        "hid_generic"        # Generic HID
        "usbhid"             # USB HID
        "libps2"             # PS/2 library
        
        # I2C and system controllers
        "i2c_i801"           # Intel I2C controller
        "i2c_smbus"          # SMBus support
        "lpc_ich"            # Intel LPC controller
        "mei"                # Intel Management Engine
        "mei_me"             # Intel ME interface
        
        # Power management and performance
        "intel_rapl_common"  # Intel RAPL common
        "intel_rapl_msr"     # Intel RAPL MSR
        "intel_cstate"       # Intel C-states
        "rapl"               # Running Average Power Limit
        
        # Cryptography
        "aesni_intel"        # Intel AES-NI acceleration
        "crypto_simd"        # SIMD crypto acceleration
        "cryptd"             # Crypto daemon
        
        # QEMU and virtualization
        "qemu_fw_cfg"        # QEMU firmware config
        "kvm"                # KVM virtualization
        "vfio"               # VFIO framework
        
        # Legacy and compatibility
        "ata_piix"           # Legacy ATA
        "mptspi"             # LSI MPT SPI
        "mpt3sas"            # LSI MPT SAS3
      ];
      
      kernelModules = [
        "dm_mod"             # Ensure device mapper loads early
        "btrfs"              # Ensure BTRFS loads early
      ];
    };
    
    # Runtime kernel modules for all hardware
    kernelModules = [
      # Virtualization support
      "kvm-intel"          # Intel VT-x support
      "kvm-amd"            # AMD-V support
      "vfio-pci"           # VFIO for GPU passthrough
      "vfio"               # VFIO core
      "vfio_iommu_type1"   # VFIO IOMMU support
      
      # GPU modules (loaded on demand)
      "amdgpu"             # AMD GPU support
      
      # Network and misc
      "tun"                # TUN/TAP for VPN
      "br_netfilter"       # Bridge netfilter
    ];
    
    # Kernel parameters for performance and compatibility
    kernelParams = [
      # Performance optimizations
      "mitigations=off"              # Disable CPU vulnerability mitigations for performance
      "preempt=full"                 # Full preemption for responsiveness
      
      # Memory management
      "transparent_hugepage=madvise" # Smart hugepage usage
      
      # Security (balanced with performance)
      "apparmor=1"                   # Enable AppArmor
      
      # Hardware compatibility
      "acpi_enforce_resources=lax"   # Relaxed ACPI for older hardware
      
      # Virtualization support
      "kvm_intel.nested=1"           # Enable nested virtualization
      "kvm_amd.nested=1"             # Enable nested virtualization
      "kvm.ignore_msrs=1"            # Ignore unhandled MSRs
      "kvm.report_ignored_msrs=0"    # Don't spam logs with MSR warnings
    ];
    
    # Additional module packages
    extraModulePackages = with config.boot.kernelPackages; [
      # ZFS support (if needed)
      # zfs
    ];
    
    # Boot configuration
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;     # Keep last 10 generations
        editor = false;              # Disable boot entry editing for security
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      timeout = 3;                   # Boot timeout in seconds
    };
    
    # Temporary filesystem in RAM
    tmp = {
      useTmpfs = true;               # Use tmpfs for /tmp (performance)
      tmpfsSize = "50%";             # Use up to 50% of RAM for /tmp
    };
  };
  
  # Comprehensive filesystem support
  boot.supportedFilesystems = [
    "btrfs"              # Primary filesystem
    "xfs"                # High-performance filesystem
    "ext4"               # Legacy compatibility
    "vfat"               # EFI boot partition
    "ntfs"               # Windows compatibility
    "zfs"                # Enterprise filesystem
  ];
  
  # ZFS configuration (requires host ID)
  networking.hostId = "12345678";  # Required for ZFS - random but consistent
  
  # Hardware support configuration
  hardware = {
    # Enable all available firmware
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    
    # Graphics support for all vendors
    graphics = {
      enable = true;
      enable32Bit = true;           # 32-bit support for gaming/Wine
      extraPackages = with pkgs; [
        # AMD
        mesa
        amdvlk                      # AMD Vulkan driver
        
        # Intel
        intel-media-driver          # Intel VAAPI
        intel-compute-runtime       # Intel OpenCL
        
        # Vulkan
        vulkan-tools
        vulkan-loader
        vulkan-validation-layers
      ];
    };
    
    # CPU-specific optimizations
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    
    # Audio support
    # pulseaudio.enable = false;      # Use PipeWire instead (configured in profiles)
  };
  
  # Advanced kernel tuning
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max" = lib.mkDefault 134217728;
    "net.core.wmem_max" = lib.mkDefault 134217728;
    "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
    
    # Virtual memory tuning
    "vm.swappiness" = lib.mkDefault 10;              # Reduce swap usage
    "vm.dirty_ratio" = lib.mkDefault 15;
    "vm.dirty_background_ratio" = lib.mkDefault 5;
    "vm.vfs_cache_pressure" = lib.mkDefault 50;
    
    # Kernel performance
    "kernel.sched_autogroup_enabled" = lib.mkDefault 0;  # Disable for server workloads
  };
  
  # Power management
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "performance";  # Can be overridden per profile
  };
  
  # Security configuration
  security = {
    apparmor = {
      enable = true;
      killUnconfinedConfinables = true;
    };
  };

  # Services for hardware support
  services = {
    # Firmware updates
    fwupd.enable = true;
    
    # Hardware detection
    udev = {
      enable = true;
      extraRules = ''
        # Optimize I/O scheduler for different device types
        ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="mq-deadline"
        ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
        ACTION=="add|change", KERNEL=="vd[a-z]*", ATTR{queue/scheduler}="mq-deadline"
        
        # GPU power management
        SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{power/control}="auto"
        SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{power/control}="auto"
        SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{power/control}="auto"
      '';
    };
    
    # Thermal management
    thermald.enable = true;
  };
  
  # Virtualization support
  virtualisation = {
    # Enable libvirt for VM management
    libvirtd = {
      enable = true;
      qemu = {
        package = lib.mkDefault pkgs.qemu_full;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };
    
    # Docker support
    docker = {
      enable = true;
      enableOnBoot = true;
      daemon.settings = {
        # Performance settings
        "storage-driver" = "overlay2";
        "log-driver" = "journald";
      };
    };
  };
}