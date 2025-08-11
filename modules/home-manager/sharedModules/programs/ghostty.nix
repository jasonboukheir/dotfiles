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
        theme = "dark:nord,light:nord-light";
        window-theme = "system";
        macos-option-as-alt = true;
      };
    };
  };
}
