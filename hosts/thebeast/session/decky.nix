{
  config,
  lib,
  ...
}: let
  cfg = config.gaming;
  steamHome = "${config.users.users.${cfg.user}.home}/.local/share/Steam";
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

    # Steam's CEF gates remote DevTools behind a magic toggle file in the
    # Steam root; Decky needs that port open to inject its frontend bundle
    # into Big Picture. Upstream Decky's install.sh drops this file
    # imperatively, but for a declarative Jovian setup we plant it via
    # tmpfiles so it survives reinstalls and isn't tied to a one-off
    # interactive setup step.
    # Reference: https://github.com/SteamDeckHomebrew/decky-loader/blob/main/dist/install_release.sh
    systemd.tmpfiles.settings."10-thebeast-gamer-cef-debugging" = {
      ${steamHome}.d = {
        mode = "0755";
        user = cfg.user;
        group = cfg.user;
      };
      "${steamHome}/.cef-enable-remote-debugging".f = {
        mode = "0644";
        user = cfg.user;
        group = cfg.user;
      };
    };
  };
}
