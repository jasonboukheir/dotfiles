{ pkgs, ... }:
{
  home-manager.users.jasonbk = {
    home.packages = [ pkgs.python312Full ];
  };
}
