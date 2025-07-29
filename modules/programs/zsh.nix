{ pkgs, lib, ... }:
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
      # perf test zsh startup
      # initContent =
      #   let
      #     zshConfigStart = lib.mkOrder 100 "zmodload zsh/zprof";
      #     zshConfigEnd = lib.mkOrder 2000 "zprof";
      #   in
      #   lib.mkMerge [
      #     zshConfigStart
      #     zshConfigEnd
      #   ];
    };
  };
}
