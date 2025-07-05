{ pkgs, inputs }:
with pkgs;
let shared-packages = import ../shared/packages.nix { inherit pkgs; }; in
shared-packages ++ [

  _1password-gui # Password manager

  brlaser # Printer driver

  chromedriver # Chrome webdriver for testing

  claude-code # Coding agent
  inputs.claude-desktop.packages."${pkgs.system}".claude-desktop-with-fhs

  discord # Voice and text chat

  gimp # Image editor
  google-chrome # Web browser

  keepassxc # Password manager

  pavucontrol # Pulse audio controls
  playerctl # Control media players from command line

  qmk # Keyboard firmware toolkit

  screenkey # Display pressed keys on screen
  simplescreenrecorder # Screen recording tool

  unixtools.ifconfig # Network interface configuration
  unixtools.netstat # Network statistics

  vlc # Media player

  xclip # Clipboard utilities

  yubikey-agent # Yubikey SSH agent
  pinentry-qt # GPG pinentry

  zathura # PDF viewer

  # Filesystem support
  ntfs3g # NTFS support
  zfs # ZFS support
  btrfs-progs # Btrfs support

  # System snapshots
  snapper # Filesystem snapshots

  # Media server
  jellyfin # Media server
  jellyfin-web # Web interface for Jellyfin
  jellyfin-ffmpeg # FFmpeg for Jellyfin

  # File sharing
  samba # SMB/CIFS support

  # Virtualization
  qemu_full # Full QEMU virtualization
  libvirt # Virtualization management
  virt-manager # GUI for libvirt
  virt-viewer # Remote viewer for VMs

  # *arr stack media management
  sonarr # TV series management
  radarr # Movie management
  lidarr # Music management
  prowlarr # Indexer management
  bazarr # Subtitle management
  jackett # Torrent/NZB indexer proxy
  qbittorrent # BitTorrent client

  # Gaming
  steam # Steam gaming platform
  steam-run # Steam runtime for running games
  protonup-qt # Proton version manager GUI
  protontricks # Wine wrapper for Steam
  winetricks # Wine helper script
  wine-staging # Wine with experimental patches
  lutris # Gaming platform manager
  mangohud # Gaming overlay
  gamemode # Gaming performance optimization
  vulkan-tools # Vulkan utilities
  vulkan-loader # Vulkan loader
  dxvk # DirectX to Vulkan translation
  occt # GPU stress testing
  geekbench # System benchmarking

  # Window manager
  hyprland # Dynamic tiling Wayland compositor
  xwayland # X11 compatibility layer for Wayland

  # Development tools
  google-cloud-sdk # Google Cloud SDK
  packer # Machine image builder
  vscode # Visual Studio Code

  # Browsers and desktop apps
  microsoft-edge # Microsoft Edge browser
  kleopatra # KDE certificate manager
  tor-browser-bundle-bin # Tor Browser

  # System monitoring
  netdata # Real-time system monitoring
  glances # System monitoring tool
  # btop # Modern system monitor (removed duplicate - defined in shared)
  nvtop # NVIDIA GPU monitoring
  amdgpu-top # AMD GPU monitoring
  iotop # I/O monitoring
  sysstat # System performance tools (sar included)
  smartmontools # Hard drive monitoring
  fastfetch # System information tool

  # Network and container tools
  gns3-gui # GNS3 network simulator GUI
  gns3-server # GNS3 network simulator server
  traefik # Cloud native application proxy
  docker # Container platform
  docker-compose # Multi-container Docker applications
  wireshark # Network protocol analyzer
  nmap # Network scanner
  iperf3 # Network performance testing
  speedtest-cli # Internet speed test
  tcpdump # Packet capture
  dog # Modern dig replacement
  dnsutils # dig and other DNS tools
  bandwhich # Network utilization by process
  bottom # System monitor
  ctop # Container monitoring
  lazydocker # Docker TUI

  # Virtualization additions
  quickemu # Quick VM creation
  spice-gtk # VM display protocol

  # Development tools
  nodejs # Node.js runtime
  cargo # Rust package manager
  go # Go programming language
  gdb # GNU Debugger
  python312 # Python 3.12

  # System utilities
  eza # Modern ls replacement
  procs # Modern ps replacement
  inotify-tools # File system event monitoring
  parallel # Run commands in parallel
  tuned # System tuning daemon
  wireplumber # PipeWire session manager

  # Compression and archives
  rar # RAR archive support
  pigz # Parallel gzip
  
  # Media tools
  ffmpeg-full # Complete FFmpeg
  mpd # Music Player Daemon
  mpv # Media player
  spotify # Music streaming
  noise-torch # Noise cancellation

  # Web server
  nginx # Web server

  # Productivity apps
  cursor # AI-powered code editor
  obsidian # Knowledge management
  todoist # Task management (if available)
  mailspring # Email client
  _1password # Already present above
  vaultwarden # Self-hosted password manager

  # Communication apps  
  whatsapp-for-linux # WhatsApp desktop client
  signal-desktop # Signal messenger
  slack # Already in shared packages

  # Shells and terminals
  powershell # PowerShell Core
  fish # Fish shell
  nushell # Modern shell
  kitty # GPU-accelerated terminal
  konsole # KDE terminal emulator

  # AI/ML tools
  aider # AI pair programming (if available)
  # lmstudio # LLM interface (might need manual installation)
  # comfyui # Stable Diffusion UI (might need manual installation)

  # Development tools
  sublime4 # Sublime Text editor
  jetbrains.idea-ultimate # IntelliJ IDEA
  jetbrains.pycharm-professional # PyCharm
  jetbrains.webstorm # WebStorm
  via # Keyboard configurator
  vial # Keyboard configurator

  # System tools
  thorium # Chromium-based browser (if available)
  timeshift # System backup tool
  flatpak # Universal package system
  gnome.gnome-software # Software discovery
  flatseal # Flatpak permissions manager
  freerdp # RDP client

  # Network services
  jellyseerr # Media request management
  samba # SMB client (smbclient included)
  autofs # Automatic filesystem mounting
  sssd # System Security Services Daemon
  wsdd # Web Service Discovery host

  # Requested packages
  ansible # Infrastructure automation
  postgresql # PostgreSQL database
  # sqlite # SQLite database (removed duplicate - defined in shared)
  libav # Audio/video library
  
  # Essential missing packages
  # System essentials
  lsof # List open files
  pciutils # lspci
  usbutils # lsusb
  dmidecode # Hardware information
  lm_sensors # Hardware monitoring
  ethtool # Network interface info
  bridge-utils # Network bridge utilities
  vlan # VLAN configuration
  
  # Security essentials
  fail2ban # Intrusion prevention
  lynis # Security auditing
  rkhunter # Rootkit scanner
  clamav # Antivirus
  aide # File integrity checker
  
  # Backup and sync
  restic # Encrypted backups
  rclone # Cloud storage sync
  syncthing # P2P file sync
  
  # Development essentials
  direnv # Already in home-manager
  pre-commit # Git hooks
  delta # Better git diff
  lazygit # Git TUI
  dbeaver # Database GUI
  postman # API testing
  insomnia # API client
  
  # System monitoring additions
  lnav # Log file navigator
  multitail # Monitor multiple logs
  dstat # System resource statistics
  atop # Advanced system monitor
  nmon # Performance monitor
  
  # Container/K8s tools
  kubectl # Kubernetes CLI
  minikube # Local Kubernetes
  helm # Kubernetes package manager
  k3s # Lightweight Kubernetes
  buildah # Container builder
  skopeo # Container image operations
  
  # File management
  ranger # Terminal file manager
  mc # Midnight Commander
  duf # Better df
  ncdu # Already added
  
  # Network tools additions
  aria2 # Download utility
  wget2 # Modern wget
  httpie # HTTP client
  curlie # Better curl
  mitmproxy # HTTPS proxy
  termshark # Terminal Wireshark UI
  
  # Productivity
  tldr # Simplified man pages
  cheat # Command cheatsheets
  taskwarrior # Task management
  calcurse # Calendar
  
  # Media additions
  obs-studio # Streaming/recording
  kdenlive # Video editor
  audacity # Audio editor
  
  # Essential CLI improvements
  sd # Better sed
  jless # JSON viewer
  gping # Graphical ping
  xh # Better HTTPie
  zellij # Terminal multiplexer
  
  # Missing essentials
  ventoy # Bootable USB creator
  gparted # Partition editor
  bleachbit # System cleaner
  baobab # Disk usage analyzer
  
  # Additional requested packages
  # System analysis
  smokeping # Network latency monitoring
  arpwatch # ARP monitoring
  linuxPackages.perf # Performance analysis
  fio # I/O benchmarking
  hdparm # Hard disk parameters
  
  # Gaming controllers
  openrgb # RGB lighting control
  
  # Development and office
  openjdk # Java Development Kit
  libreoffice # Office suite
  openldap # LDAP tools (includes ldapsearch)
  
  # Filesystem tools
  fuse # Filesystem in userspace
  fuse3 # FUSE 3 support
  google-cloud-sdk # GCloud SDK
  gcsfuse # Google Cloud Storage FUSE
  
  # Vulkan additions
  vulkan-validation-layers # Already added in hardware config
  vkcube # Vulkan demo
  
  # Network services
  adguardhome # DNS ad blocker
  nfs-utils # NFS utilities

  # Screenshot and screen recording
  kazam # Screen recorder
  ksnip # Screenshot tool

  # System management
  stacer # System optimizer/cleaner
  # missioncenter # System monitor (may need AppImage/Flatpak)
  bleachbit # Already added above
  clamtk # ClamAV GUI
  ps_mem # Memory usage by process
  cfdisk # Curses-based disk partitioner
  gparted # Already added above

  # Productivity and communication
  ferdi # Multi-service messaging (Franz alternative)
  zoom-us # Video conferencing
  # bluemail # Email client (may need AppImage/Flatpak)
  drawio # Diagrams and flowcharts
  localsend # Local file sharing

  # Media and graphics
  blender # 3D graphics suite
  musikcube # Terminal-based music player
  qimgv # Fast image viewer
  # upscayl # AI image upscaler (may need AppImage/Flatpak)
  # frog # OCR tool (may need Flatpak)
  # buzz # Transcription tool (may need manual install)

  # CLI utilities
  cmatrix # Matrix digital rain
  mcfly # Shell history search
  howdoi # Command line answers
  diff-so-fancy # Better git diff
  fdupes # Find duplicate files
  hyperfine # Command-line benchmarking
  difftastic # Already added above
  miller # Data processing tool
  # transfer.sh client (manual script install)
  himalaya # Email client

  # Additional apps
  diodon # Clipboard manager
  # normcap # Screen text extraction (may need Flatpak)
  whisper-cpp # OpenAI Whisper speech recognition
  okular # Document viewer
  terminator # Terminal emulator
  # fsearch # File search (may need manual build)

  # LibreOffice additions (Draw already included in libreoffice)
  libreoffice-fresh # Ensure latest version

  # File managers
  nemo # Cinnamon file manager
  thunar # XFCE file manager (lightweight)
  xfce.thunar-volman # Volume manager for Thunar
  xfce.thunar-archive-plugin # Archive support for Thunar

  # Hyprland ecosystem
  wofi # Application launcher for Wayland
  waybar # Status bar for Wayland
  hyprpaper # Wallpaper utility for Hyprland
  dunst # Notification daemon
]
