{
  lib,
  config,
  ...
}: {
  home-manager.sharedModules = lib.optionals config.stylix.enable [
    {stylix.targets.qt.platform = "qtct";}
    {gtk.gtk4.theme = null;}
  ];
}
