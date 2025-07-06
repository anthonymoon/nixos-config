# Secrets configuration for agenix
# This file defines public keys for encrypting secrets
let
  # Add your SSH public keys here
  user = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."; # Replace with actual key
  
  # Add system host keys here
  system = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."; # Replace with actual key
  
  # Define all public keys
  allKeys = [ user system ];
in
{
  # Example secret files
  # "user-password.age".publicKeys = allKeys;
  # "database-password.age".publicKeys = allKeys;
  # "ssh-key.age".publicKeys = allKeys;
}