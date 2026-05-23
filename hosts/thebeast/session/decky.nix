{
  config,
  lib,
  ...
}: let
  cfg = config.gaming;
in {
  config = lib.mkIf cfg.enable {
    # Decky Loader is the GamepadUI plugin host — required because Valve
    # ships no public theming API for `steam -gamepadui`, so all theming
    # paths route through process-injected CSS via the CSS Loader plugin
    # (installed once interactively from the Decky store; see Phase 2 of
    # https://github.com/jasonboukheir/nix-config/issues/29).
    #
    # Jovian's module runs the loader as root and setuids down to the
    # unprivileged user named here. Pinning that user to gamer (rather
    # than the upstream `decky` default) keeps plugins' filesystem
    # access aligned with the Steam install they target.
    # TODO: confirm the upstream-mandated root→user drop still works
    # when user != "decky" —
    # https://github.com/SteamDeckHomebrew/decky-loader/issues/446
    jovian.decky-loader = {
      enable = true;
      user = cfg.user;
    };
  };
}
