{
  config,
  lib,
  ...
}: {
  # defaultApps.nix declares options that other parts of the codebase
  # may reference — keep it imported unconditionally. The Hyprland-
  # specific settings nested inside the other files only take effect
  # when wayland.windowManager.hyprland.enable is true, so the single
  # gate below is enough to keep the gamer Plasma session quiet.
  imports = [
    ./autostart.nix
    ./bindings.nix
    ./defaultApps.nix
    ./envs.nix
    ./input.nix
    ./looknfeel.nix
    ./monitor.nix
    ./windows.nix
  ];

  config = lib.mkIf config.omarchy.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
    };
    services.hyprpolkitagent.enable = true;

    # home-manager's wayland services (hyprsunset, hypridle,
    # hyprpolkitagent, …) default to WantedBy=graphical-session.target,
    # but on this host plasma-login-manager pulls graphical-session.target
    # active *before* Hyprland runs `dbus-update-activation-environment
    # --systemd` to push WAYLAND_DISPLAY into the user systemd env. The
    # services then trip ConditionEnvironment=WAYLAND_DISPLAY (or, worse,
    # inherit a stale WAYLAND_DISPLAY from a prior Hyprland session) and
    # fall into a Restart=on-failure loop until Hyprland's env update
    # finally lands — observed as ~25s of "Couldn't connect to a wayland
    # compositor" / "Failed to connect to Wayland display" spam after
    # every re-login (issue #32 items 2 + 3 + the hyprpolkitagent line
    # of item 4).
    #
    # hyprland-session.target is started by Hyprland itself *after* the
    # wayland socket is published and the env update has completed, so
    # services wanted-by that target see the right WAYLAND_DISPLAY on
    # their first attempt. The BindsTo=graphical-session.target wiring
    # in the upstream hyprland-session.target unit still tears them
    # down cleanly on logout.
    wayland.systemd.target = "hyprland-session.target";
  };
}
