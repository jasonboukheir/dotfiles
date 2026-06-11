# Native home for the GTK settings the retired home-manager gtk module and
# HM-stylix's home.pointerCursor used to carry (issue #48). GTK loads
# settings.ini from every XDG_CONFIG_DIRS entry and then XDG_CONFIG_HOME,
# merging per-key with later files winning — so this /etc/xdg fallback
# supplies the icon and cursor themes wherever the user file doesn't set
# them, while Plasma's GTK Settings Sync keeps owning gamer's user files
# outright.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omarchy;

  # System stylix cursor (the per-user stylix cursor has no consumer here —
  # /etc/xdg is one system-scope file). The real stylix asserts cursor
  # name/package/size all-or-none, so keying on package alone is exact there;
  # it also keeps hosts and tests without the stylix module — or with a
  # partial stub that only sets cursor.size (my-hyprland-config) — evaluating.
  cursor = let
    c =
      if config ? stylix
      then config.stylix.cursor or null
      else null;
  in
    if c != null && (c.package or null) != null
    then c
    else null;

  settingsIni = lib.generators.toINI {} {
    Settings =
      {
        gtk-icon-theme-name = cfg.iconTheme.name;
      }
      // lib.optionalAttrs (cursor != null) {
        gtk-cursor-theme-name = cursor.name;
        gtk-cursor-theme-size = cursor.size;
      };
  };
in {
  options.omarchy.iconTheme = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "breeze-dark";
      description = ''
        GTK icon theme name written to the system-wide
        /etc/xdg/gtk-{3,4}.0/settings.ini. Stylix sets gtk-theme-name but not
        gtk-icon-theme-name, so GTK would fall back to hicolor — which has no
        app icons, leaving wofi's drun list as text-only.
      '';
    };
    package = lib.mkPackageOption pkgs ["kdePackages" "breeze-icons"] {
      extraDescription = ''
        Must ship share/icons/<name> for the configured icon theme name so the
        theme is resolvable from the system profile's XDG_DATA_DIRS.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [cfg.iconTheme.package]
      ++ lib.optional (cursor != null) cursor.package;
    environment.etc."xdg/gtk-3.0/settings.ini".text = settingsIni;
    environment.etc."xdg/gtk-4.0/settings.ini".text = settingsIni;
  };
}
