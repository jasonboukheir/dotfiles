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
        font-size = 13;
        window-theme = "system";
        macos-option-as-alt = true;
      };
    };
  };
}
