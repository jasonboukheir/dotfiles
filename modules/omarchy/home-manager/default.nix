{...}: {
  home-manager.sharedModules = [
    ./hyprland
    ./btop.nix
    ./hypridle.nix
    ./mako.nix
    ./waybar.nix
    ./wofi.nix
  ];
}
