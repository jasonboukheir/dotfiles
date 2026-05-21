{
  config,
  lib,
  ...
}: let
  dmCfg = config.thebeast;
  preselectSession = "${dmCfg.greeterDefaultSession}.desktop";
  usePlasmaLoginManager = dmCfg.displayManager == "plasma-login-manager";
in {
  # Jovian's autoStart sets [General].DefaultSession = gamescope-wayland
  # because gamer is the autologin user. mkForce: when the greeter
  # actually appears (only after explicit logout — see relogin=false
  # in session/jovian-steam.nix) jasonbk is the only one looking at it,
  # and they want the session highlighted to be Hyprland rather than
  # gamescope.
  services.displayManager.sddm.settings.General.DefaultSession =
    lib.mkForce preselectSession;

  # Opt-in path: replace SDDM with KDE's new Plasma Login Manager.
  # Jovian also forces sddm.enable=true, so the override has to be
  # mkForce. Both DMs read services.displayManager.autoLogin, so the
  # gamer→gamescope autologin keeps working untouched.
  services.displayManager.sddm.enable =
    lib.mkIf usePlasmaLoginManager (lib.mkForce false);
  services.displayManager.plasma-login-manager = lib.mkIf usePlasmaLoginManager {
    enable = true;
    # PreselectedSession is the plasmalogin.conf equivalent of SDDM's
    # General.DefaultSession — same per-user-default caveat applies
    # (the value is global, not per-user; harmless here because gamer
    # never reaches the greeter).
    settings.Greeter.PreselectedSession = preselectSession;
  };
}
