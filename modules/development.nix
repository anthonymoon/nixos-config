# Development Environment Module
# Essential development tools and services

{ config, pkgs, lib, username ? null, ... }:

{
  options.modules.development.enable = lib.mkEnableOption "development environment";

  config = lib.mkIf config.modules.development.enable {
    # Development packages
    environment.systemPackages = with pkgs; [
      # Version control
      gh
      gitui
      
      # Editors and IDEs
      vscode
      vim
      neovim
      
      # Programming languages
      nodejs_22
      python3
      python3Packages.pip
      rustc
      cargo
      go
      
      # Build tools
      gnumake
      cmake
      pkg-config
      
      # Container tools
      docker
      docker-compose
      podman
      
      # Network tools
      curl
      wget
      httpie
      
      # Database tools
      sqlite
      postgresql
      
      # Cloud tools
      awscli2
      terraform
      
      # Monitoring
      btop
      iotop
      
      # Development utilities
      jq
      yq
      tree
      fd
      ripgrep
      fzf
      direnv
      tmux
      screen
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
      ];
    };
    
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
    };
    
    # Enable direnv for automatic environment loading
    programs.direnv.enable = true;
    
    # Networking for development
    networking.firewall.allowedTCPPorts = [
      3000 3001 3002 3003  # Common dev ports
      8000 8001 8080 8081  # Common dev ports
      5432  # PostgreSQL
      6379  # Redis
    ];
  };
}