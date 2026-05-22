{
  config,
  lib,
  ...
}: {
  home-manager.extraSpecialArgs = {
    systemConfig.omarchy = config.omarchy;
  };
  home-manager.sharedModules = lib.optionals config.omarchy.enable [
    ./options.nix
    ./calendar
    ./hyprland
    ./btop.nix
    ./clipse.nix
    ./gtk.nix
    ./hypridle.nix
    ./hyprlock.nix
    ./hyprsunset.nix
    ./mako.nix
    ./onepassword.nix
    ./waybar.nix
    ./wl-clip-persist.nix
    ./wofi.nix
  ];
}
