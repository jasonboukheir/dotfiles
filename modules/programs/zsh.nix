{ pkgs, ... }:
{
  programs.zsh.enable = true;
  home-manager.users.jasonbk = {
    programs.zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" ];
      };
      shellAliases = {
        git = "${pkgs.git}/bin/git";
      };
    };
  };
}
