{
  lib,
  config,
  ...
}: {
  home-manager.sharedModules = lib.optional config.stylix.enable
    {stylix.targets.qt.platform = "qtct";};
  imports = [
  ];
}
