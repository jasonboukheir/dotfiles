{config, ...}: let
  cursorSize = toString config.stylix.cursor.size;
  envPair = name: value: {_args = [name value];};
in {
  wayland.windowManager.hyprland.settings = {
    env = [
      (envPair "XCURSOR_SIZE" cursorSize)
      (envPair "HYPRCURSOR_SIZE" cursorSize)

      (envPair "GDK_BACKEND" "wayland")
      (envPair "QT_QPA_PLATFORM" "wayland")
      (envPair "QT_STYLE_OVERRIDE" "kvantum")
      (envPair "SDL_VIDEODRIVER" "wayland")
      (envPair "MOZ_ENABLE_WAYLAND" "1")
      (envPair "ELECTRON_OZONE_PLATFORM_HINT" "wayland")
      (envPair "OZONE_PLATFORM" "wayland")

      # XDG_DATA_DIRS is set up by PAM-session (NixOS environment.sessionVariables)
      # and inherited by Hyprland. Don't re-set it here: the Lua `hl.env` API
      # calls setenv() with the literal string, so a `$XDG_DATA_DIRS:$HOME/...`
      # template ends up as literal `$VAR` substrings in the path, corrupting
      # XDG lookups (wofi drops apps, GTK fails to resolve icons).

      # glib's g_time_zone_new_local() reads the zone name from
      # /etc/localtime and resolves it under $TZDIR. NixOS only exports
      # TZDIR via /etc/set-environment (login shells) and
      # systemd.globalEnvironment, neither of which reach a Hyprland
      # session launched by plasma-login-manager, so GUI-launched glib
      # apps get a NULL GTimeZone — gnome-calendar aborts on it.
      (envPair "TZDIR" "/etc/zoneinfo")

      (envPair "XCOMPOSEFILE" "~/.XCompose")
      (envPair "EDITOR" "nvim")
    ];

    config = {
      xwayland = {
        force_zero_scaling = true;
      };

      # Don't show update on first launch
      ecosystem = {
        no_update_news = true;
      };
    };
  };
}
