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
    ./gtk.nix
  ];
}
