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
        ++ lib.optionals gamingEnabled ["gamemode" "uinput" "video" "render"];
      group = "${gameUser}";
      home = "/home/${gameUser}";
      isNormalUser = true;
      # Passwordless. SDDM autoLogin uses the sddm-autologin PAM stack
      # (pam_permit). For manual "Switch User" greeter clicks, jovian.nix
      # sets sddm.General.EmptyPassword=true so SDDM forwards "" to the
      # regular sddm→login PAM stack, which accepts it via nullok.
      hashedPassword = "";
    };
    users.jasonbk.extraGroups = lib.optionals gamingEnabled ["gamemode" "input"];
  };
}
