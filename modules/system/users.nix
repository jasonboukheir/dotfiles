{ pkgs, ... }:
{
  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.zsh;
  };
  nix.settings.trusted-users = [
    "root"
    "jasonbk"
    "@admin"
  ];
}
