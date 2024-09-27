{ pkgs, ... }:
{
  home-manager.users.jasonbk = {
    home.packages = [ pkgs.kitty ];
    programs.kitty = {
      enable = true;
      themeFile = "Nord";
      font = {
        name = "FiraCode Nerd Font Mono";
        size = 12.0;
      };
      settings = {
        cursor_shape = "underline";
      };

      shellIntegration.mode = "no-cursor";
    };
  };
}
