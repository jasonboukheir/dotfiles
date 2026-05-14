{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
in
  lib.mkIf config.gaming.enable {
    gaming.user = "gamer";

    jovian.steam.enable = true;
    jovian.steam.user = cfg.user;
    jovian.steamos.useSteamOSConfig = false;
    jovian.devices.steamdeck.enable = false;
    jovian.hardware.has.amd.gpu = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    services.desktopManager.plasma6.enable = true;

    # SDDM with autologin gamer only on initial SDDM start (relogin=false).
    # Boot     → autologin → gamescope-wayland (default session)
    # Logout   → SDDM greeter (no relogin), gamer/jasonbk both pickable
    # Switch User from Plasma → fresh SDDM greeter (no autologin re-fire)
    # Switch to Desktop from Steam → steamosctl writes
    #   /etc/sddm.conf.d/zzt-steamos-temp-login.conf with Session=plasma; the
    #   sddm-temp-login-watcher.path below kicks SDDM so the initial-start
    #   autologin consumes the temp config and lands the user in plasma.
    services.displayManager = {
      autoLogin = {
        enable = true;
        user = cfg.user;
      };
      sddm = {
        enable = true;
        wayland.enable = true;
        autoLogin.relogin = false;
      };
      defaultSession = "gamescope-wayland";
    };

    # steamos-manager marker — without this steamos-manager refuses to manage
    # the seat (Switch to Desktop / Switch to Game Mode become no-ops).
    environment.etc."sddm.conf.d/steamos.conf".text = "";

    # Replicate jovian's "force the user's preferred desktop session" oneshot.
    # Steam occasionally clobbers steamos-manager's stored desktop preference,
    # so re-set it every time graphical-session.target comes up.
    systemd.user.services.jovian-setup-desktop-session = {
      wants = ["steamos-manager.service"];
      after = ["steamos-manager.service"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.steamos-manager}/bin/steamosctl set-default-desktop-session plasma.desktop";
      };
    };

    # The cleanup service exists already (from jovian.steam.enable) but isn't
    # wired into graphical-session.target without autoStart — add the binding
    # so temp-login configs get cleaned at every session start.
    systemd.user.services.steamos-manager-session-cleanup = {
      overrideStrategy = "asDropin";
      wantedBy = ["graphical-session.target"];
    };

    # gamescope-session env override (matches jovian's autoStart behavior):
    # null out PATH so the wrapper picks its own, and propagate XKB defaults.
    systemd.user.services.gamescope-session = {
      overrideStrategy = "asDropin";
      environment = lib.mkMerge (
        [{PATH = lib.mkForce null;}]
        ++ map (var:
          lib.mkIf (config.environment.variables ? ${var}) {
            ${var} = lib.mkDefault config.environment.variables.${var};
          }) [
          "XKB_DEFAULT_LAYOUT"
          "XKB_DEFAULT_OPTIONS"
          "XKB_DEFAULT_MODEL"
          "XKB_DEFAULT_RULES"
          "XKB_DEFAULT_VARIANT"
        ]
      );
    };

    xdg.portal.configPackages = lib.mkDefault [pkgs.gamescope-session];

    # Switch-to-Desktop / Switch-to-Game-Mode round-trip with relogin=false:
    # steamosctl writes /etc/sddm.conf.d/zzt-steamos-temp-login.conf and stops
    # graphical-session.target. Without relogin SDDM would just show the
    # greeter and the temp config would never be consumed. This path unit
    # kicks display-manager whenever the temp config appears so the fresh
    # SDDM hits initial-start autologin, which honors the temp Session=.
    systemd.paths.sddm-temp-login-watcher = {
      wantedBy = ["multi-user.target"];
      pathConfig.PathExists = "/etc/sddm.conf.d/zzt-steamos-temp-login.conf";
    };
    systemd.services.sddm-temp-login-watcher = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl --no-block restart display-manager.service";
      };
    };
  }
