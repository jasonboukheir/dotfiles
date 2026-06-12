{
  config,
  lib,
  pkgs,
  ...
}: let
  # The greeter used to ship a copy of Plasma's breeze sddm theme with a
  # stylix wallpaper overlay. When plasma6 left the closure (#78) the
  # theme's QML imports (org.kde.breeze.components, kirigami, libplasma,
  # ...) went with it and sddm silently fell back to its embedded theme;
  # restoring them would mean carrying a KDE QML stack just for a login
  # box. where-is-my-sddm-theme is plain QtQuick — wallpaper, a single
  # password field, session/user labels — themed here from system stylix.
  wallpaper =
    if (config ? stylix) && (config.stylix.enable or false)
    then config.stylix.image or null
    else null;
  colors = config.lib.stylix.colors.withHashtag;
  cursor = config.stylix.cursor or null;

  greeterTheme = pkgs.where-is-my-sddm-theme.override {
    themeConfig.General = {
      background = "${wallpaper}";
      # FastBlur clamps at 64; this is the full frosted-glass strength.
      blurRadius = 64;
      backgroundFill = colors.base00;
      basicTextColor = colors.base05;
      passwordTextColor = colors.base05;
      passwordCursorColor = colors.base05;
      font = config.stylix.fonts.monospace.name;
      helpFont = config.stylix.fonts.monospace.name;
      # Two-account machine: show which user the password goes to and
      # which session it starts (gamescope vs hyprland) instead of a
      # bare field.
      showUsersByDefault = true;
      showSessionsByDefault = true;
      # gamer's password is empty (see users.nix); the theme's Enter
      # handler refuses to submit an empty field unless this is set,
      # which forced typing a throwaway character to log in.
      passwordAllowEmpty = true;
    };
  };
in {
  config = lib.mkIf (wallpaper != null) {
    environment.systemPackages = [greeterTheme];
    services.displayManager.sddm = {
      theme = "where_is_my_sddm_theme";
      # Qt5Compat.GraphicalEffects and QtSvg are the theme's only QML
      # imports; the stock sddm greeter environment ships neither.
      extraPackages = [pkgs.qt6.qt5compat pkgs.qt6.qtsvg];
      # breeze_cursors left the closure with plasma; stylix's cursor
      # package is installed system-wide, which is where the greeter's
      # kwin resolves XCursor themes from.
      settings.Theme = lib.mkIf (cursor != null) {
        CursorTheme = cursor.name;
        CursorSize = cursor.size;
      };
    };
  };
}
