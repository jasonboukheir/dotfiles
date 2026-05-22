{...}: {
  # Add startup commands by appending entries that produce
  # `hl.on("hyprland.start", function() hl.exec_cmd("...") end)`.
  # See https://wiki.hypr.land/Configuring/Basics/Autostart for examples.
  wayland.windowManager.hyprland.settings = {};
}
