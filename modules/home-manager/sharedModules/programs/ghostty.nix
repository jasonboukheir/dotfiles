{
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkIf config.programs.ghostty.enable {
    programs.ghostty = {
      package = lib.mkIf pkgs.stdenv.isDarwin null;
      settings = {
        font-size = 13;
        font-family = "FiraCode Nerd Font";
        theme = "dark:Nord,light:Nord Light";
        window-theme = "system";
        macos-option-as-alt = true;
      };
    };
  };
}
