{
  config,
  lib,
  pkgs,
  ...
}: let
  dmCfg = config.thebeast;
  # Both DMs run their greeter as a dedicated system user and read the
  # KDE color scheme from that user's ~/.config/kdeglobals — SDDM's
  # breeze greeter from /var/lib/sddm (what sddm-kcm's "Apply Plasma
  # Settings" writes imperatively), plasma-login-manager's from
  # /var/lib/plasmalogin.
  greeterUser =
    if dmCfg.displayManager == "plasma-login-manager"
    then "plasmalogin"
    else "sddm";
  greeterHome = "/var/lib/${greeterUser}";

  gamerUser = config.gaming.user;
  # The tests/test-overrides.nix path clears home-manager.users entirely;
  # guarded access keeps the stylix integration evaluable in that case.
  gamerHm = config.home-manager.users.${gamerUser} or null;

  # stylix-kde-theme: lookandfeel package, color-scheme file, wallpaper
  # package. stylix-kde-config: the immutable kdeglobals / kcminputrc the
  # KDE HM target normally feeds into the user via xdg.systemDirs.config.
  # Both are runCommandLocal derivations with stable `name` attrs.
  themePackage =
    if gamerHm == null
    then null
    else lib.findFirst (p: (p.name or "") == "stylix-kde-theme") null gamerHm.home.packages;
  configPath =
    if gamerHm == null
    then null
    else lib.findFirst (p: lib.hasInfix "stylix-kde-config" (toString p)) null gamerHm.xdg.systemDirs.config;

  ready = themePackage != null && configPath != null;

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
    (lib.mkIf ready {
      # System-wide install puts the lookandfeel, color-scheme, and
      # wallpaper under /run/current-system/sw/share/, where the greeter
      # can resolve them via kpackage/XDG.
      environment.systemPackages = [themePackage];

      # Seed the greeter user's plasma config. The LookAndFeelPackage=stylix
      # entry in kdeglobals is what the KDE KCM's "Apply Plasma Settings"
      # button writes here imperatively — doing it via tmpfiles keeps it
      # declarative and lets new stylix outputs roll through with
      # `nixos-rebuild switch` instead of needing the GUI.
      # L+ replaces the symlink on each rebuild so closure bumps land.
      systemd.tmpfiles.settings."10-login-greeter-stylix" = {
        ${greeterHome}.d = {
          user = greeterUser;
          group = greeterUser;
          mode = "0750";
        };
        "${greeterHome}/.config".d = {
          user = greeterUser;
          group = greeterUser;
          mode = "0750";
        };
        "${greeterHome}/.config/kdeglobals"."L+" = {
          argument = "${configPath}/kdeglobals";
          user = greeterUser;
          group = greeterUser;
        };
        "${greeterHome}/.config/kcminputrc"."L+" = {
          argument = "${configPath}/kcminputrc";
          user = greeterUser;
          group = greeterUser;
        };
      };
    })
  ];
}
