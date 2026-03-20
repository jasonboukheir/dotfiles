{
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkIf config.programs.ghostty.enable {
    programs.ghostty = {
      package = lib.mkIf pkgs.stdenv.isDarwin pkgs.ghostty-bin;
      settings = {
        window-theme = "auto";
        macos-option-as-alt = true;
        unfocused-split-opacity = 0.7;
      };
    };
  };
}
