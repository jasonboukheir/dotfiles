{
  config,
  lib,
  pkgs,
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

  # The omarchy.uwsm.enable fallback: what HM's hyprland systemd
  # integration ran from exec-once — export the session vars and recycle
  # hyprland-session.target (provided natively below, now that the HM
  # module is gone).
  fallbackVars = ["DISPLAY" "HYPRLAND_INSTANCE_SIGNATURE" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP" "XDG_SESSION_TYPE"];
  fallbackCmd = lib.concatStringsSep " && " [
    "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd ${toString fallbackVars}"
    "systemctl --user stop hyprland-session.target"
    "systemctl --user start hyprland-session.target"
  ];

  startCmd =
    if config.omarchy.uwsm.enable
    then "uwsm finalize ${toString finalizeVars}"
    else fallbackCmd;
in {
  config = lib.mkIf config.omarchy.enable (lib.mkMerge [
    {
      # Add startup commands by appending entries that produce
      # `hl.on("hyprland.start", function() hl.exec_cmd("...") end)`.
      # See https://wiki.hypr.land/Configuring/Basics/Autostart for examples.
      my.hyprland.settings.on = [
        {
          _args = [
            "hyprland.start"
            (inline ''function() hl.exec_cmd("${startCmd}") end'')
          ];
        }
      ];
    }
    (lib.mkIf (!config.omarchy.uwsm.enable) {
      # What HM's hyprland integration declared; the omarchy units bind to
      # it through omarchy.sessionTarget when uwsm is off.
      systemd.user.targets.hyprland-session = {
        description = "Hyprland compositor session";
        documentation = ["man:systemd.special(7)"];
        bindsTo = ["graphical-session.target"];
        wants = ["graphical-session-pre.target"];
        after = ["graphical-session-pre.target"];
      };
    })
  ]);
}
