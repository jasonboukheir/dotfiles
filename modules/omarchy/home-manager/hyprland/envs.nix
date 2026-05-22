{
  config,
  ...
}: let
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

      (envPair "XDG_DATA_DIRS" "$XDG_DATA_DIRS:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share")

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
