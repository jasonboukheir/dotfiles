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
    ./hyprsunset.nix
    ./onepassword.nix
    ./wl-clip-persist.nix
  ];
}
