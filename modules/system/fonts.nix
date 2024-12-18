{ pkgs, ... }:
{
  home-manager.users.jasonbk.home = {
    packages = with pkgs; [ nerd-fonts.fira-code ];
  };
}
