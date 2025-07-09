# Development Environment Module
# Essential development tools and services

{ config, pkgs, lib, username ? null, ... }:

{
  options.modules.development.enable = lib.mkEnableOption "development environment";

  config = lib.mkIf config.modules.development.enable {
    # Development packages
    environment.systemPackages = with pkgs; [
      # Version control
      gh  # GitHub CLI
      gitui
      
      # Editors and IDEs
      vscode
      vim
      neovim
      
      # AI Development Tools  
      # claude-code - may not be in stable
      # gemini - needs custom package
      
      # Programming languages
      nodejs_22
      nodePackages.npm
      python312
      python312Packages.pip
      (python312.withPackages (ps: with ps; [
        chromadb
      ]))
      # python312Packages.uvx - may need pipx instead
      rustc
      cargo
      go
      
      # Build tools
      gnumake
      cmake
      pkg-config
      
      # Container & Virtualization tools
      docker
      docker-compose
      podman
      qemu_full
      libvirt
      virt-manager
      virt-viewer
      spice-vdagent
      
      # Network tools
      curl
      wget
      httpie
      socat
      netcat
      
      nmap
      tcpdump
      
      # Database tools
      sqlite
      postgresql
      redis
      # chromadb - needs python package
      
      # Infrastructure as Code
      terraform
      packer
      argocd
      jenkins
      
      # System tools
      
      
      # Monitoring
      btop
      iotop
      multitail
      
      # Terminal multiplexers
      tmux
      zellij
      screen
      
      # Development utilities
      jq  # JSON processor
      yq  # YAML processor
      
      tree
      fd  # Find alternative
      ripgrep  # grep alternative
      gawk  # GNU awk
      fzf  # Fuzzy finder
      direnv
      zoxide  # Smart cd
      # zinit - ZSH plugin manager, configured separately
      
      # VS Code Server support
      # vscode-server - needs special handling
    ];
    
    
    
    # Enable PostgreSQL for development
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        local all all scram-sha-256
        host all all 127.0.0.1/32 scram-sha-256
        host all all ::1/128 scram-sha-256
      '';
      
    };
    
    # Enable nginx for development
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
    };
    
    # Enable Redis for development
    services.redis.servers.development = {
      enable = true;
      port = 6379;
      bind = "127.0.0.1";
    };
    
    # Git configuration
    programs.git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };
    
    # Add user to development groups
    users.users = lib.mkIf (username != null) {
      ${username}.extraGroups = [ 
        "docker" 
        "postgres"
        "libvirtd"
        "kvm"
      ];
    };
    
    # Enable libvirt for virtualization
    virtualisation.libvirtd = {
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
    
    # Enable QEMU guest agent for VMs
    services.qemuGuest.enable = true;

    
    
    
    
    
    
    
    
    # Enable direnv for automatic environment loading
    programs.direnv.enable = true;

    environment.etc."zshrc".text = ''
      # Initialize zoxide
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
      # Configure zinit if available
      # source ${pkgs.zinit}/share/zinit/zinit.zsh

      # Oh My Zsh setup (manual)
      # This assumes Oh My Zsh is installed globally or for the user
      # If not, you might need to install it first
      # export ZSH="/usr/share/oh-my-zsh"
      # source $ZSH/oh-my-zsh.sh

      # Shell Aliases
      alias ll="ls -la"
      alias la="ls -la"
      alias ..="cd .."
      alias ...="cd ../.."
      alias gs="git status"
      alias gc="git commit"
      alias gp="git push"
      alias gl="git pull"
      alias gd="git diff"
      alias docker-clean="docker system prune -af"
    '';
    
    # Firewall disabled per requirements
    # Port configurations removed
  };
}