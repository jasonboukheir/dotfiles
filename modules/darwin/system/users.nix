{ pkgs, ... }:
{
  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.nushell;
    uid = 501;
  };
  users.knownUsers = [ "jasonbk" ];
  nix.settings.trusted-users = [
    "root"
    "jasonbk"
    "@admin"
  ];
}
