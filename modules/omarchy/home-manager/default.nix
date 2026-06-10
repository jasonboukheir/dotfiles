{
  config,
  lib,
  ...
}: {
  home-manager.sharedModules = lib.optionals config.omarchy.enable [
    ./calendar
    ./btop.nix
    ./gtk.nix
  ];
}
