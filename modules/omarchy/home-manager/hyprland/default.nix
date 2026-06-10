{
  config,
  lib,
  systemConfig,
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

    # Remaining home-manager wayland services follow the same session
    # target as the native omarchy units (see omarchy.sessionTarget for
    # why that is hyprland-session.target and not graphical-session.target
    # today — issue #32).
    wayland.systemd.target = systemConfig.omarchy.sessionTarget;
  };
}
