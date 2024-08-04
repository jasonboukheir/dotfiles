{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    initExtra = ''
    eval "$(starship init zsh)"
    '';
  };
}