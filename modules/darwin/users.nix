{pkgs, ...}: {
  users.users.jasonbk = {
    home = "/Users/jasonbk";
    shell = pkgs.fish;
    uid = 501;
  };
  users.knownUsers = ["jasonbk"];
  nix.settings.trusted-users = [
    "root"
    "jasonbk"
    "@admin"
  ];
}
