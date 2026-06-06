{
  config,
  lib,
  ...
}: let
  dmCfg = config.thebeast;
  preselectSession = "${dmCfg.greeterDefaultSession}.desktop";
  usePlasmaLoginManager = dmCfg.displayManager == "plasma-login-manager";
in {
  # Jovian sets services.displayManager.defaultSession = "gamescope-wayland",
  # which NixOS' sddm module folds into a computed default for
  # General.DefaultSession and then merges *under* sddm.settings via
  # recursiveUpdate. Writing settings.General.DefaultSession directly wins
  # without needing an override priority. The greeter only appears after an
  # explicit logout (see relogin=false in session/jovian-steam.nix), and at
  # that point the only user looking at it is jasonbk.
  services.displayManager.sddm.settings.General.DefaultSession = preselectSession;

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
