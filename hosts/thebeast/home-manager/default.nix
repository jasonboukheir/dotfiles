{
  lib,
  config,
  ...
}: {
  imports = [
    ./sharedModules
  ];
  home-manager.users.jasonbk.imports = [./jasonbk];
  home-manager.users.gamer.imports =
    [./gamer]
    ++ lib.optionals config.stylix.enable [
      {stylix.enable = false;}
    ];
}
