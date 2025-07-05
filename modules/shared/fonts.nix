{ pkgs, ... }:

with pkgs; [
  dejavu_fonts
  emacs-all-the-icons-fonts
  font-awesome
  hack-font
  jetbrains-mono
  meslo-lgs-nf
  noto-fonts
  noto-fonts-emoji
  
  # Nerd Fonts
  (nerdfonts.override { fonts = [ 
    "FiraCode" 
    "DroidSansMono" 
    "Hack" 
    "Iosevka" 
    "JetBrainsMono"
    "Meslo"
    "RobotoMono"
    "SourceCodePro"
    "UbuntuMono"
  ]; })
  
  # Windows fonts
  corefonts # Microsoft Core Fonts
  vistafonts # Windows Vista fonts
]
