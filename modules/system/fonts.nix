{ pkgs, ... }:
{
  home-manager.users.jasonbk.home = {
    packages = with pkgs; [ nerdfonts.fira_code ];
  };
}
