{
  lib,
  config,
  ...
}: {
  home-manager.sharedModules =
    lib.optional config.stylix.enable
    {stylix.targets.qt.platform = "qtct";}
    ++ [
      {gtk.gtk4.theme = null;}
    ];
  imports = [
  ];
}
