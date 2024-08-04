{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
    };
    ignores = [
      ".DS_Store"
    ];
  };
}