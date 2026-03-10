{osConfig, ...}: {
  imports = [
    ../../stylix
  ];
  stylix.enable = osConfig.stylix.enable;
}
