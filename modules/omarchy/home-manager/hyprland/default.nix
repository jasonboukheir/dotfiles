{systemConfig, ...}: {
  # Everything here is per-session state: hyprland.conf only takes
  # effect inside a Hyprland session, so applying it to every user
  # (including gamer, whose default session is Plasma) is safe.
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

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    # Under UWSM the session manager owns env export (`uwsm finalize`,
    # see autostart.nix) and the session target lifecycle; HM's
    # integration would fight it by stop/starting hyprland-session.target
    # from exec-once. Flips back together with omarchy.uwsm.enable.
    systemd.enable = !systemConfig.omarchy.uwsm.enable;
  };

  # Remaining home-manager wayland services follow the same session
  # target as the native omarchy units (see omarchy.sessionTarget for
  # why that is hyprland-session.target and not graphical-session.target
  # today — issue #32).
  wayland.systemd.target = systemConfig.omarchy.sessionTarget;
}
