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
    
    # Firewall disabled per requirements
    # Advanced firewall rules removed
    
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
    ];
    
    # Note: Automatic security updates are disabled by default in server profile
    # due to flake path constraints in pure evaluation mode
    
    # Enhanced SSH security - only when security module is enabled
    services.openssh.settings = {
      PasswordAuthentication = lib.mkForce false;
      PermitRootLogin = lib.mkForce "no";
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
    
    
    
    # AIDE configuration (manual setup required)
    # AIDE is included in the main systemPackages list above
    # Run: sudo aide --init && sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  };
}