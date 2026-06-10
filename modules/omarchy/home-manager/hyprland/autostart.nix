{
  lib,
  systemConfig,
  ...
}: let
  inline = lib.generators.mkLuaInline;

  # The vars HM's systemd integration used to export via
  # dbus-update-activation-environment; `uwsm finalize` pushes them (plus
  # WAYLAND_DISPLAY, always included) into the systemd activation
  # environment and then notifies wayland-wm@Hyprland.service, which is
  # what lets units After=omarchy.sessionTarget see the socket first-try
  # (issue #32) and what completes the uwsm session startup at all —
  # without finalize the Type=notify unit times out after 30s and the
  # session is torn down.
  finalizeVars = ["DISPLAY" "HYPRLAND_INSTANCE_SIGNATURE" "XDG_CURRENT_DESKTOP"];
in {
  # Add startup commands by appending entries that produce
  # `hl.on("hyprland.start", function() hl.exec_cmd("...") end)`.
  # See https://wiki.hypr.land/Configuring/Basics/Autostart for examples.
  wayland.windowManager.hyprland.settings = {
    on = lib.optionals systemConfig.omarchy.uwsm.enable [
      {
        _args = [
          "hyprland.start"
          (inline ''function() hl.exec_cmd("uwsm finalize ${toString finalizeVars}") end'')
        ];
      }
    ];
  };
}
