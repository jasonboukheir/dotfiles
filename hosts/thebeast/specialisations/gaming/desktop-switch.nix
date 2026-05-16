{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
  tempConf = "/etc/sddm.conf.d/zzt-steamos-temp-login.conf";
  sessionsRoot = "${config.services.displayManager.sessionData.desktops}/share";

  # Steamos-manager implements "Switch to Desktop" by writing
  # [Autologin]/Session=<name>.desktop to /etc/sddm.conf.d/zzt-steamos-
  # temp-login.conf and then restarting display-manager.service. We're not
  # running SDDM (display-manager.service is aliased to greetd.service),
  # but the restart still triggers — so we have greetd's gaming entrypoint
  # parse the same temp-conf and exec the requested wayland session. No
  # SDDM, no patching steamos-manager.
  #
  # Defaults to gamescope-wayland when the override is absent. The cleanup
  # oneshot below (mirrors jovian's wiring) deletes the temp file shortly
  # after the new session reaches graphical-session.target, so the next
  # logout naturally falls back to gamescope.
  sessionWrapper = pkgs.writeShellApplication {
    name = "thebeast-gamer-session";
    runtimeInputs = with pkgs; [gawk gnused coreutils gamescope-session];
    text = ''
      tempConf=${lib.escapeShellArg tempConf}
      defaultSession=gamescope-wayland.desktop
      sessionDirs=(
        ${lib.escapeShellArg "${sessionsRoot}/wayland-sessions"}
        ${lib.escapeShellArg "${sessionsRoot}/xsessions"}
      )

      requested=""
      if [ -r "$tempConf" ]; then
        requested=$(awk -F= '
          /^Session=/ {
            sub(/^[[:space:]]+/, "", $2)
            sub(/[[:space:]]+$/, "", $2)
            print $2
            exit
          }' "$tempConf")
      fi

      session=''${requested:-$defaultSession}
      case "$session" in
        *.desktop) ;;
        *) session="$session.desktop" ;;
      esac

      for dir in "''${sessionDirs[@]}"; do
        candidate="$dir/$session"
        [ -r "$candidate" ] || continue
        execLine=$(sed -n 's/^Exec=//p' "$candidate" | head -n1)
        if [ -n "$execLine" ]; then
          # Probe path used by the VM test to inspect resolution without
          # actually launching a wayland session.
          if [ "''${1:-}" = "--print-resolved" ]; then
            printf '%s\n' "$execLine"
            exit 0
          fi
          exec sh -c "$execLine"
        fi
      done

      if [ "''${1:-}" = "--print-resolved" ]; then
        printf 'fallback:start-gamescope-session\n'
        exit 0
      fi
      echo "thebeast-gamer-session: $session not found, falling back to $defaultSession" >&2
      exec start-gamescope-session
    '';
  };
in {
  options.gaming.sessionEntrypoint = lib.mkOption {
    type = lib.types.path;
    internal = true;
    readOnly = true;
    default = "${sessionWrapper}/bin/thebeast-gamer-session";
    description = "Greetd entrypoint for gamer that proxies steamos-manager's SDDM override.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [sessionWrapper];

    # Plasma 6 provides the wayland-sessions/plasma.desktop entry that
    # the wrapper hands off to when steamos-manager sets the override.
    services.desktopManager.plasma6.enable = true;

    # steamos-manager probes this directory to know whether it's allowed
    # to manage sessions; jovian installs the same marker under autoStart.
    environment.etc."sddm.conf.d/steamos.conf".text = "";

    # Failsafe: if the system rebooted while a temp override was staged
    # (e.g. crash mid-plasma), drop it once on boot so the next gaming
    # login isn't quietly redirected to a stale desktop session.
    systemd.tmpfiles.rules = [
      "r! ${tempConf} - - - - -"
    ];

    # Jovian only installs jovian-setup-desktop-session +
    # steamos-manager-session-cleanup under jovian.steam.autoStart, which
    # we've disabled (we use greetd autologin instead). Re-create them so
    # steamos-manager's DefaultDesktopSession property is populated and
    # the temp override is cleaned up after each desktop session.
    systemd.user.services.jovian-setup-desktop-session = {
      wants = ["steamos-manager.service"];
      after = ["steamos-manager.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.steamos-manager}/bin/steamosctl set-default-desktop-session plasma.desktop";
      };
      wantedBy = ["graphical-session.target"];
    };

    systemd.user.services.steamos-manager-session-cleanup = {
      overrideStrategy = "asDropin";
      wantedBy = ["graphical-session.target"];
    };
  };
}
