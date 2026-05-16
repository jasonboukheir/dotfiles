{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
  tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
  hyprlandSessions = "${pkgs.hyprland}/share/wayland-sessions";

  # Wrapper script (defined in gaming/desktop-switch.nix) that picks the
  # session from steamos-manager's SDDM temp-conf override, defaulting to
  # gamescope. Keeps Steam's "Switch to Desktop" → plasma flow working
  # without enabling SDDM.
  gamingSession = {
    command = cfg.sessionEntrypoint;
    user = cfg.user;
  };

  devSession = {
    command = "${tuigreet} --time --remember --remember-session --sessions ${hyprlandSessions}";
    user = "greeter";
  };
in {
  services.greetd = {
    enable = true;
    settings =
      if cfg.enable
      then {
        initial_session = gamingSession;
        default_session = gamingSession;
      }
      else {
        default_session = devSession;
      };
  };

  systemd.services.greetd = {
    serviceConfig = {
      Type = "idle";
      StandardError = "journal";
    };
    # NixOS defaults greetd to X-RestartIfChanged=false so rebuilds don't yank
    # the user out of their session. The dev/gaming swap has the opposite
    # need: switch-to-configuration must restart greetd to apply the new
    # default_session, otherwise the spec flip is silent until reboot.
    restartIfChanged = lib.mkForce true;
  };
}
