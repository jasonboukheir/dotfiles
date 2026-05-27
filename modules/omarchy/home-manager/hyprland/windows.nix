{...}: {
  wayland.windowManager.hyprland.settings = {
    # See https://wiki.hypr.land/Configuring/Window-Rules for more
    window_rule = [
      {
        match = {class = ".*";};
        suppress_event = "maximize";
      }

      # Force chromium into a tile to deal with --app bug
      {
        match = {class = "^(chromium)$";};
        tile = true;
      }

      # Settings management
      {
        match = {class = "^(org.pulseaudio.pavucontrol|blueberry.py)$";};
        float = true;
      }

      # Float Steam, fullscreen RetroArch
      {
        match = {class = "^(steam)$";};
        float = true;
      }
      {
        match = {class = "^(steam)$";};
        center = true;
      }
      {
        match = {class = "^(com.libretro.RetroArch)$";};
        fullscreen = true;
      }

      # Just dash of transparency
      {
        match = {class = ".*";};
        opacity = "1 0.97";
      }
      # Normal chrome Youtube tabs
      {
        match = {
          class = "^(chromium|google-chrome|google-chrome-unstable|helium)$";
          title = ".*[Yy]ou[Tt]ube.*";
        };
        opacity = "1 1";
      }
      {
        match = {class = "^(chromium|google-chrome|google-chrome-unstable)$";};
        opacity = "1 0.97";
      }
      {
        match = {initial_class = "^(chrome-.*-Default)$";};
        opacity = "1 0.97";
      } # web apps
      {
        match = {initial_class = "^(chrome-[Yy]ou[Tt]ube.*-Default)$";};
        opacity = "1 1";
      } # YouTube
      {
        match = {class = "^(zoom|vlc|org.kde.kdenlive|com.obsproject.Studio)$";};
        opacity = "1 1";
      }
      {
        match = {class = "^(com.libretro.RetroArch|steam)$";};
        opacity = "1 1";
      }

      # Fix some dragging issues with XWayland
      {
        match = {
          class = "^$";
          title = "^$";
          xwayland = true;
          float = true;
          fullscreen = false;
          pin = false;
        };
        no_focus = true;
      }

      # Float in the middle for clipse clipboard manager
      {
        match = {class = "(clipse)";};
        float = true;
      }
      {
        match = {class = "(clipse)";};
        size = "622 652";
      }
      {
        match = {class = "(clipse)";};
        stay_focused = true;
      }
    ];

    layer_rule = [
      # Proper background blur for wofi
      {
        match = {namespace = "wofi";};
        blur = true;
      }
      {
        match = {namespace = "waybar";};
        blur = true;
      }
    ];
  };
}
