{config, lib, ...}: let
  cursorSize = toString config.stylix.cursor.size;
in {
  wayland.windowManager.hyprland.settings = {
    env = [
      "GDK_SCALE,2"
      "XCURSOR_SIZE,${cursorSize}"
      "HYPRCURSOR_SIZE,${cursorSize}"

      "GDK_BACKEND,wayland"
      "QT_QPA_PLATFORM,wayland"
      "QT_STYLE_OVERRIDE,kvantum"
      "SDL_VIDEODRIVER,wayland"
      "MOZ_ENABLE_WAYLAND,1"
      "ELECTRON_OZONE_PLATFORM_HINT,wayland"
      "OZONE_PLATFORM,wayland"

      "XDG_DATA_DIRS,$XDG_DATA_DIRS:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share"

      "XCOMPOSEFILE,~/.XCompose"
      "EDITOR,nvim"
    ];

    xwayland = {
      force_zero_scaling = true;
    };

    # Don't show update on first launch
    ecosystem = {
      no_update_news = true;
    };
  };
}
