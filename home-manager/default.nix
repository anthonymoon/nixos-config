# Home Manager configuration for user amoon
{ config, pkgs, lib, ... }:

{
  home.username = "amoon";
  home.homeDirectory = "/home/amoon";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "23.11";

  # User packages - reproduced from Arch Linux system
  home.packages = with pkgs; [
    # Terminal and shell
    kitty
    ghostty
    kdePackages.konsole
    fish
    zsh
    bash-completion
    btop
    htop
    
    # Development tools
    git
    neovim
    vscode-insiders
    
    # System utilities
    rsync
    screen
    zellij
    multitail
    mosh
    
    # Network tools
    aws-cli
    
    # Media and fonts
    font-awesome
    
    # Build tools
    bc
    
    # Archive tools
    cdrtools
    
    # System monitoring
    btrfs-progs
    
    # Cloud and infrastructure
    ansible
    
    # Networking
    bind
    
    # Bluetooth
    bluez
    bluez-tools
    
    # Audio
    alsa-utils
    
    # Package management
    nix-search-cli
    
    # System information
    fastfetch
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "amoon";
    userEmail = "amoon@starbux.us";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  # Shell configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    bashrcExtra = ''
      export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
      export PATH="$HOME/.npm-global/bin:$PATH"
      export SHELL=/bin/zsh
      export UPSTASH_REDIS_REST_URL="http://localhost:7379"
      export UPSTASH_REDIS_REST_TOKEN="local-token"
    '';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    initExtra = ''
      export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
      export PATH="$HOME/.npm-global/bin:$PATH"
      export UPSTASH_REDIS_REST_URL="http://localhost:7379"
      export UPSTASH_REDIS_REST_TOKEN="local-token"
    '';
  };

  programs.fish = {
    enable = true;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    shellInit = ''
      set -gx DOCKER_HOST unix://$XDG_RUNTIME_DIR/docker.sock
      set -gx PATH $HOME/.npm-global/bin $PATH
      set -gx SHELL /bin/zsh
      set -gx UPSTASH_REDIS_REST_URL "http://localhost:7379"
      set -gx UPSTASH_REDIS_REST_TOKEN "local-token"
    '';
  };

  # Kitty terminal configuration
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrains Mono";
      size = 12;
    };
    settings = {
      background_opacity = "0.9";
      background = "#1d1f21";
      foreground = "#c5c8c6";
      cursor = "#c5c8c6";
      selection_background = "#373b41";
      selection_foreground = "#c5c8c6";
    };
  };

  # Neovim configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # Htop configuration
  programs.htop = {
    enable = true;
    settings = {
      show_program_path = true;
      tree_view = true;
    };
  };

  # Zellij configuration
  programs.zellij = {
    enable = true;
    settings = {
      theme = "tokyo-night";
      default_shell = "zsh";
      copy_command = "wl-copy";
    };
  };

  # Home Manager itself
  programs.home-manager.enable = true;

  # XDG directories
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    videos = "$HOME/Videos";
    templates = "$HOME/Templates";
    publicShare = "$HOME/Public";
  };

  # Session variables
  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "firefox";
    TERMINAL = "kitty";
    DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
  };

  # Directory creation
  home.file.".config/claude-code/.keep".text = "";
  home.file.".config/nvim/.keep".text = "";
  home.file.".config/gh/.keep".text = "";
  home.file.".config/go/.keep".text = "";
  home.file.".config/libvirt/.keep".text = "";
  home.file.".config/yay/.keep".text = "";
  home.file.".config/kitty/.keep".text = "";
  home.file.".config/zellij/.keep".text = "";
  home.file.".npm-global/.keep".text = "";
}