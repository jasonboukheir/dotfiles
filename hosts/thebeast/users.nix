{config, ...}: let
  gameUser = config.gaming.user;
in {
  systemd.tmpfiles.rules = [
    "d /games/home/gamer 0755 ${gameUser} ${gameUser} -"
  ];

  users = {
    # Declarative passwords are a prerequisite for system.etc.overlay —
    # without them the overlay's fresh upper layer shadows the rootfs
    # /etc/shadow on first boot and locks every interactive account.
    mutableUsers = false;

    groups.${gameUser} = {
      name = "${gameUser}";
    };

    users.${gameUser} = {
      description = "${gameUser}";
      extraGroups = ["networkmanager" "input" "gamemode"];
      group = "${gameUser}";
      home = "/home/${gameUser}";
      isNormalUser = true;
    };
    users.jasonbk = {
      extraGroups = ["gamemode" "input"];
      hashedPasswordFile = config.age.secrets."users/jasonbk/password".path;
    };
  };
}
