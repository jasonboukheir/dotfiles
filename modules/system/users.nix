{ pkgs, ... }:
{
  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.zsh;
  };
}
