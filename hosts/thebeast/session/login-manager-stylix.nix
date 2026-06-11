{
  config,
  lib,
  pkgs,
  ...
}: let
  dmCfg = config.thebeast;
  # The greeter's KDE *color-scheme* seeding (kdeglobals/kcminputrc +
  # the LookAndFeelPackage entry) used to borrow the gamer user's
  # home-manager stylix `kde` target outputs (stylix-kde-theme /
  # stylix-kde-config). thebeast is now home-manager-free (#57) and the
  # stylix `kde` target only exists in the HM stylix module, so that
  # block was dropped. The greeter wallpaper below survives because it
  # comes from system stylix (config.stylix.image), not HM.
  # TODO(#78): re-derive a system-stylix KDE theme/config for the
  # greeter (and gamer's Plasma), or retire KDE on gamer.
  wallpaper =
    if (config ? stylix) && (config.stylix.enable or false)
    then config.stylix.image or null
    else null;

  # SDDM's breeze theme pins `background=` to the stock Next wallpaper
  # inside its store-path theme.conf. The supported override is a
  # theme.conf.user next to it (what sddm-kcm's imperative "Apply Plasma
  # Settings" writes), which the read-only store rules out — so ship a
  # copy of the theme carrying that overlay with the stylix wallpaper.
  # SDDM discovers it by directory name under
  # /run/current-system/sw/share/sddm/themes (Theme.ThemeDir).
  breezeStylixTheme = pkgs.runCommand "breeze-stylix-sddm-theme" {} ''
    mkdir -p $out/share/sddm/themes
    cp -r --no-preserve=mode \
      ${pkgs.kdePackages.plasma-desktop}/share/sddm/themes/breeze \
      $out/share/sddm/themes/breeze-stylix
    printf '[General]\nbackground=%s\n' '${wallpaper}' \
      > $out/share/sddm/themes/breeze-stylix/theme.conf.user
  '';
in {
  config = lib.mkMerge [
    (lib.mkIf (dmCfg.displayManager == "sddm" && wallpaper != null) {
      environment.systemPackages = [breezeStylixTheme];
      services.displayManager.sddm = {
        theme = "breeze-stylix";
        # The sddm module's breeze cursor defaults key off the literal
        # theme name "breeze"; replicate them for the renamed copy.
        settings.Theme = {
          CursorTheme = "breeze_cursors";
          CursorSize = 24;
        };
      };
    })
  ];
}
