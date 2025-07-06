# Secrets Management

This directory contains encrypted secrets managed by [agenix](https://github.com/ryantm/agenix).

## Setup

1. Add your SSH public keys to `secrets.nix`
2. Add your system's host keys to `secrets.nix`
3. Create and encrypt secrets using: `agenix -e <secret-name>.age`

## Usage

```bash
# Create a new secret
agenix -e user-password.age

# Edit an existing secret
agenix -e user-password.age

# Re-key all secrets (after updating keys)
agenix --rekey
```

## Integration

Secrets are automatically decrypted at boot time and placed in `/run/agenix/` for use by services.

Example configuration in NixOS:

```nix
age.secrets.user-password.file = ../secrets/user-password.age;
users.users.myuser.passwordFile = config.age.secrets.user-password.path;
```