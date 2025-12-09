{
  config,
  lib,
  ...
}: {
  home-manager.sharedModules = lib.optionals config.omarchy.enable [
    ./hyprland
    ./btop.nix
    ./hypridle.nix
    ./mako.nix
    ./waybar.nix
    ./wofi.nix
  ];
}
