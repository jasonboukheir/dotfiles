{osConfig, ...}: {
  stylix.cursor = {
    inherit (osConfig.stylix.cursor) name package;
    size = 12;
  };
}
