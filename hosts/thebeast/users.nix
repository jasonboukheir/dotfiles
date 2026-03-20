{
  config,
  lib,
  ...
}: let
  gameUser = config.gaming.user;
  gamingEnabled = config.gaming.enable;
in {
  systemd.tmpfiles.rules = [
    "d /games/home/gamer 0755 ${gameUser} ${gameUser} -"
  ];

  users = {
    groups.${gameUser} = {
      name = "${gameUser}";
    };

    users.${gameUser} = {
      description = "${gameUser}";
      extraGroups =
        ["networkmanager" "input"]
        ++ lib.optionals gamingEnabled ["gamemode"];
      group = "${gameUser}";
      home = "/home/${gameUser}";
      isNormalUser = true;
    };
    users.jasonbk.extraGroups = lib.optionals gamingEnabled ["gamemode" "input"];
  };
}
