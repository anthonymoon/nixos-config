# Media Server Module
# Self-hosted media automation stack

{ config, pkgs, lib, ... }:

let
  cfg = config.modules.media-server;
  mediaRoot = "/storage/media";
  downloadRoot = "/storage/downloads";
  
  # Service ports
  ports = {
    jackett = 9117;
    radarr = 7878;
    sonarr = 8989;
    lidarr = 8686;
    jellyseerr = 5055;
    qbittorrent = 8090;
    jellyfin = 8096;
    homepage = 3000;
  };

in {
  options.modules.media-server = {
    enable = lib.mkEnableOption "media server stack";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Domain name for the media server";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Docker for additional containers
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";
    
    # Native NixOS services
    services = {
      # Jackett - Torrent indexer
      jackett = {
        enable = true;
        openFirewall = false;
        dataDir = "/var/lib/jackett";
      };
      
      # Radarr - Movie management
      radarr = {
        enable = true;
        openFirewall = false;
        dataDir = "/var/lib/radarr";
        user = "radarr";
        group = "media";
      };
      
      # Sonarr - TV management
      sonarr = {
        enable = true;
        openFirewall = false;
        dataDir = "/var/lib/sonarr";
        user = "sonarr";
        group = "media";
      };
      
      # Lidarr - Music management
      lidarr = {
        enable = true;
        openFirewall = false;
        dataDir = "/var/lib/lidarr";
        user = "lidarr";
        group = "media";
      };
      
      # Jellyfin - Media server
      jellyfin = {
        enable = true;
        openFirewall = false;
        user = "jellyfin";
        group = "media";
      };
      
      # Samba for network shares
      samba = {
        enable = true;
        openFirewall = true;
        
        settings = {
          global = {
            "workgroup" = "WORKGROUP";
            "server string" = "NixOS Media Server";
            "security" = "user";
            "guest account" = "nobody";
            "map to guest" = "Bad User";
            
            # Performance tuning
            "socket options" = "TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072";
            "use sendfile" = true;
            "aio read size" = 16384;
            "aio write size" = 16384;
            "write cache size" = 262144;
            
            # Security
            "server min protocol" = "SMB3";
            "server smb encrypt" = "desired";
          };
          
          media = {
            path = mediaRoot;
            browseable = "yes";
            writable = "yes";
            "guest ok" = "no";
            "create mask" = "0664";
            "directory mask" = "0775";
            "force user" = config.myUser.username;
            "force group" = "media";
            "vfs objects" = "catia fruit streams_xattr";
          };
          
          downloads = {
            path = downloadRoot;
            browseable = "yes";
            writable = "yes";
            "guest ok" = "no";
            "create mask" = "0664";
            "directory mask" = "0775";
            "force user" = config.myUser.username;
            "force group" = "media";
          };
        };
      };
      
    };
    
    # qBittorrent service (using systemd - no native NixOS service available)
    systemd.services.qbittorrent = {
      description = "qBittorrent Daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "qbittorrent";
        Group = "media";
        UMask = "0002";
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=${toString ports.qbittorrent}";
        Restart = "on-failure";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/qbittorrent" downloadRoot ];
      };
    };
    
    # Jellyseerr service (using docker - no native NixOS service available)
    virtualisation.oci-containers.containers.jellyseerr = {
      image = "fallenbagel/jellyseerr:latest";
      ports = [ "${toString ports.jellyseerr}:5055" ];
      volumes = [
        "/var/lib/jellyseerr:/app/config"
      ];
      environment = {
        TZ = config.time.timeZone;
        UMASK = "022";
      };
      extraOptions = [ "--network=host" ];
    };
    
    # Create storage directories
    systemd.tmpfiles.rules = [
      "d ${mediaRoot} 0775 ${config.myUser.username} media -"
      "d ${downloadRoot} 0775 ${config.myUser.username} media -"
      "d /var/lib/jackett 0750 jackett jackett -"
      "d /var/lib/radarr 0750 radarr media -"
      "d /var/lib/sonarr 0750 sonarr media -"
      "d /var/lib/lidarr 0750 lidarr media -"
      "d /var/lib/jellyseerr 0750 jellyseerr media -"
      "d /var/lib/qbittorrent 0750 qbittorrent media -"
    ];
    
    # Create service users
    users.users = {
      jackett = {
        group = "jackett";
        home = "/var/lib/jackett";
        createHome = false;
        isSystemUser = true;
      };
      qbittorrent = {
        group = "media";
        home = "/var/lib/qbittorrent";
        createHome = false;
        isSystemUser = true;
      };
      jellyseerr = {
        group = "media";
        home = "/var/lib/jellyseerr";
        createHome = false;
        isSystemUser = true;
      };
    };
    
    users.groups = {
      jackett = { gid = 979; };
      media = { gid = 980; };
    };
    
    # Add main user to media group
    users.users.${config.myUser.username}.extraGroups = [ "media" ];
    
    # Networking
    networking.firewall.allowedTCPPorts = [
      ports.jellyfin
      139 445  # Samba
    ];
    
    networking.firewall.allowedUDPPorts = [
      137 138  # Samba
    ];
  };
}