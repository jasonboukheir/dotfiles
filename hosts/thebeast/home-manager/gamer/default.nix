{osConfig, ...}: {
  home.stateVersion = "25.11";
  stylix.cursor = {
    inherit (osConfig.stylix.cursor) name package;
    size = 12;
  };
}
