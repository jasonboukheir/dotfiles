{ pkgs, ... }:
{
  # homebrew.casks = [ "zed" ];
  home-manager.users.jasonbk = {
    home.packages = [ pkgs.zed-editor ]
    home.file = {
      ".config/zed" = {
        source = ./zed;
        recursive = true;
      };
    };
  };
}
