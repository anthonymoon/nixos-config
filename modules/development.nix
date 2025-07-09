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
      nodejs_24
      nodePackages.npm
      python312
      python312Packages.pip
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
      netcat-gnu
      inetutils
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
      # tuned
      
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
      # jg  # JSON grep - package not available
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
      
      # ChromaDB via Python
      (python312.withPackages (ps: with ps; [
        chromadb
      ]))
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
    
    # Enable tuned for performance optimization
    # services.tuned = {
    #   enable = true;
    #   recommendedProfile = "virtual-guest";
    # };
    
    
    # Development shell configuration
    programs.zsh = {
      enable = true;
      ohMyZsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [ "git" "docker" "kubectl" "helm" ];
      };
      shellAliases = {
        ll = "ls -la";
        la = "ls -la";
        ".." = "cd ..";
        "..." = "cd ../..";
        gs = "git status";
        gc = "git commit";
        gp = "git push";
        gl = "git pull";
        gd = "git diff";
        docker-clean = "docker system prune -af";
      };
      interactiveShellInit = ''
        # Initialize zoxide
        eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
        # Configure zinit if available
        # source ${pkgs.zinit}/share/zinit/zinit.zsh
      '';
    };
    
    # Enable direnv for automatic environment loading
    programs.direnv.enable = true;
    
    # Firewall disabled per requirements
    # Port configurations removed
  };
}