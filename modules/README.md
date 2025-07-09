# NixOS Modules

This directory contains optional modules that can be enabled in your NixOS configuration to add specific functionality.

## Available Modules

### 🎮 Gaming Module (`gaming.nix`)
Comprehensive gaming setup with Steam, Wine, and performance optimizations.

**Features:**
- Steam with extended package support
- GameMode for performance optimization
- Lutris, Bottles, Heroic game launchers
- Wine and Proton compatibility layers
- MangoHUD and performance monitoring
- Controller support (Xbox controllers)
- Low-latency audio configuration

**Usage:**
```nix
modules.gaming.enable = true;
```

### 🎬 Media Server Module (`media-server.nix`)
Complete self-hosted media automation stack.

**Features:**
- Radarr, Sonarr, Lidarr (media management)
- Jackett (torrent indexer proxy)
- qBittorrent (download client)
- Jellyfin (media server)
- Jellyseerr (media requests)
- Samba shares for network access
- Automatic directory and user setup

**Usage:**
```nix
modules.media-server = {
  enable = true;
  domain = "yourdomain.com";  # Optional
};
```

**Storage:** Creates `/storage/media` and `/storage/downloads` directories.

### 💻 Development Module (`development.nix`)
Essential development environment with tools and services.

**Features:**
- Programming languages (Node.js, Python, Rust, Go)
- Development tools (VS Code, Git, Docker)
- Database services (PostgreSQL, Redis)
- Cloud tools (AWS CLI, Terraform)
- Shell configuration (Zsh with Oh My Zsh)
- Development aliases and utilities

**Usage:**
```nix
modules.development.enable = true;
```

### 🔒 Security Module (`security.nix`)
Enhanced security hardening for servers.

**Features:**
- Fail2ban intrusion prevention
- Advanced firewall rules with rate limiting
- Security-hardened kernel parameters
- Automatic security updates
- SSH security hardening
- Intrusion detection (AIDE)
- Security monitoring tools

**Usage:**
```nix
modules.security.enable = true;
```

## Module Integration

Modules are automatically imported in the relevant profiles:

- **Workstation**: Gaming + Development modules
- **Server**: Security module (+ optional Media Server)
- **VM**: No additional modules (keep it minimal)

## Customization

You can override module settings in your profile. For example:

```nix
# In your profile
modules = {
  gaming.enable = true;
  development.enable = true;
  media-server = {
    enable = true;
    domain = "homelab.local";
  };
};

# Override specific settings
services.postgresql.enable = lib.mkForce false;  # Disable PostgreSQL from dev module
```

## Adding New Modules

1. Create a new `.nix` file in this directory
2. Use the module system pattern with `options` and `config`
3. Import it in the relevant profile
4. Add enable option to the profile configuration

Example module structure:
```nix
{ config, lib, pkgs, ... }:

{
  options.modules.mymodule.enable = lib.mkEnableOption "my custom module";

  config = lib.mkIf config.modules.mymodule.enable {
    # Your configuration here
  };
}
```