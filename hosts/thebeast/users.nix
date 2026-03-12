{config, ...}: let
  gameUser = config.gaming.user;
in {
  # Ensure the gamer home directory exists on the games drive
  systemd.tmpfiles.rules = [
    "d /games/home/gamer 0755 ${gameUser} ${gameUser} -"
  ];

  users = {
    groups.${gameUser} = {
      name = "${gameUser}";
    };

    users.${gameUser} = {
      description = "${gameUser}";
      extraGroups = ["gamemode" "networkmanager" "input" "wheel" "podman"];
      group = "${gameUser}";
      home = "/home/${gameUser}";
      isNormalUser = true;
    };
    users.jasonbk = {
      extraGroups = ["gamemode" "input"];
    };
  };
}
