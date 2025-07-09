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
        "usb_storage"        # USB storage devices
        "sd_mod"             # SCSI disk support
        "sr_mod"             # SCSI CD/DVD support
        "rtsx_pci_sdmmc"     # Realtek card readers
        
        # Virtio support (for VMs)
        "virtio_pci"         # Virtio PCI interface
        "virtio_blk"         # Virtio block devices
        "virtio_net"         # Virtio network
        "virtio_scsi"        # Virtio SCSI
        
        # Device mapper and storage
        "dm_mod"             # Device mapper core
        "dm_cache"           # Device mapper caching
        "dm_crypt"           # Device mapper encryption
        "dm_raid"            # Device mapper RAID
        "dm_snapshot"        # Device mapper snapshots
        
        # Filesystems
        "btrfs"              # BTRFS filesystem
        "xfs"                # XFS filesystem
        "ext4"               # EXT4 filesystem
        "vfat"               # FAT32 (for EFI)
        
        # Network and I/O
        "e1000e"             # Intel Ethernet
        "r8169"              # Realtek Ethernet
        "ixgbe"              # Intel 10GbE
        "thunderbolt"        # Thunderbolt support
        
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
      "security=apparmor"            # Use AppArmor as LSM
      
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
    "zfs"                # Enterprise filesystem (if enabled)
  ];
  
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
        mesa.drivers
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
    pulseaudio.enable = false;      # Use PipeWire instead
  };
  
  # Advanced kernel tuning
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = "bbr";
    
    # Virtual memory tuning
    "vm.swappiness" = 10;              # Reduce swap usage
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
    
    # Kernel performance
    "kernel.sched_autogroup_enabled" = 0;  # Disable for server workloads
  };
  
  # Power management
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "performance";  # Can be overridden per profile
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
        package = pkgs.qemu_full;
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