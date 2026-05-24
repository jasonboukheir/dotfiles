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
      # SteamOS parity: gamer logs in via jovian autoLogin and any
      # Switch-User dialog should accept an empty password.
      hashedPassword = "";
    };
    users.jasonbk = {
      extraGroups = ["gamemode" "input"];
      hashedPasswordFile = config.age.secrets."users/jasonbk/password".path;
    };
    users.root.hashedPasswordFile = config.age.secrets."users/root/password".path;
  };

  # pam_unix rejects empty passwords by default; gamer's empty
  # hashedPassword needs nullok on every PAM stack that might
  # authenticate it. jovian autoLogin bypasses PAM, so this matters
  # for su gamer and for Switch-User from plasma back through the
  # greeter. Both greeters are listed so flipping
  # thebeast.displayManager doesn't silently lock the path.
  security.pam.services.su.allowNullPassword = true;
  security.pam.services.login.allowNullPassword = true;
  security.pam.services.sddm.allowNullPassword = true;
  security.pam.services.plasma-login-manager.allowNullPassword = true;
}
