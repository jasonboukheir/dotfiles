{ pkgs, ... }:
{
  imports = [
    ./defaults/AdLib.nix
    ./defaults/desktopservices.nix
    ./defaults/dock.nix
    ./defaults/finder.nix
    ./defaults/Safari.nix
    ./defaults/screencapture.nix
    ./defaults/SoftwareUpdate.nix
  ];
}
