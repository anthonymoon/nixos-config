# Secrets configuration for agenix
# This file defines public keys for encrypting secrets
let
  # Add your SSH public keys here (replace with actual keys)
  user = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA898oqxREsBRW49hvI92CPWTebvwPoUeMSq5VMyzoM3 amoon@starbux.us";
  
  # Add system host keys here (replace with actual system keys)
  system = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvO42WS2ho4imfIVgYvm4PLRCj+0TyFY+jWou4mulbQ";
  
  # Define all public keys
  allKeys = [ user system ];
in
{
  # Example secret files - uncomment and use as needed
  "user-password.age".publicKeys = allKeys;
  "database-password.age".publicKeys = allKeys;
  "ssh-key.age".publicKeys = allKeys;
}