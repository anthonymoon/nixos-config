# Security Hardening Module
# Enhanced security configuration for servers

{ config, pkgs, lib, ... }:

{
  options.modules.security.enable = lib.mkEnableOption "security hardening";

  config = lib.mkIf config.modules.security.enable {
    # Fail2ban for intrusion prevention
    services.fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
      
      jails = {
        sshd = {
          settings = {
            enabled = true;
            port = "ssh";
            filter = "sshd";
            logpath = "/var/log/auth.log";
            maxretry = 3;
            bantime = 3600;
          };
        };
      };
    };
    
    # Advanced firewall rules
    networking.firewall = {
      enable = true;
      allowPing = false;
      logReversePathDrops = true;
      logRefusedConnections = true;
      logRefusedPackets = true;
      
      extraCommands = ''
        # Rate limiting for SSH
        iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
        iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
        
        # Drop invalid packets
        iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
      '';
    };
    
    # Security kernel parameters
    boot.kernel.sysctl = {
      # Network security
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;
      
      # Memory protection
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.yama.ptrace_scope" = 1;
      
      # File system protection
      "fs.protected_hardlinks" = 1;
      "fs.protected_symlinks" = 1;
      "fs.suid_dumpable" = 0;
    };
    
    # AppArmor security framework
    security.apparmor = {
      enable = true;
      killUnconfinedConfinables = true;
    };
    
    # Disable unnecessary services
    systemd.services = {
      debug-shell.enable = false;
    };
    
    # Secure boot loader
    boot.loader.systemd-boot.editor = false;
    
    # Security packages
    environment.systemPackages = with pkgs; [
      fail2ban
      aide
      chkrootkit
      clamav
      lynis
      rkhunter
    ];
    
    # Automatic security updates (already configured in server profile)
    system.autoUpgrade = {
      enable = true;
      allowReboot = false;
      flake = "/etc/nixos";
      flags = [ "--update-input" "nixpkgs" "--commit-lock-file" ];
      dates = "daily";
      randomizedDelaySec = "45min";
    };
    
    # Enhanced SSH security
    services.openssh = {
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = false;
        MaxAuthTries = 3;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
        Protocol = 2;
        
        # Crypto hardening
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
          "aes256-ctr"
          "aes192-ctr"
          "aes128-ctr"
        ];
        
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
          "diffie-hellman-group-exchange-sha256"
        ];
        
        Macs = [
          "hmac-sha2-256-etm@openssh.com"
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256"
          "hmac-sha2-512"
        ];
      };
    };
    
    # Log monitoring
    services.journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=7day
      ForwardToSyslog=yes
    '';
    
    # Intrusion detection
    services.aide = {
      enable = true;
      config = ''
        database=file:/var/lib/aide/aide.db
        database_out=file:/var/lib/aide/aide.db.new
        gzip_dbout=yes
        
        # Rules
        /bin FIPSR
        /sbin FIPSR
        /usr/bin FIPSR
        /usr/sbin FIPSR
        /etc FIPSR
      '';
    };
  };
}