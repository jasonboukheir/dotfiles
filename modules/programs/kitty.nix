{ pkgs, ... }:
{
  home-manager.users.jasonbk = {
    home.packages = [ pkgs.kitty ];
    programs.kitty = {
      enable = true;
      theme = "Nord";
      font = {
        name = "FiraCode";
        size = 12.0;
      };
      settings = {
        cursor_shape = "underline";
      };

      shellIntegration.mode = "no-cursor";
    };
  };
}
