{
  config,
  lib,
  pkgs,
  ...
}: let
  # Steam's preloader/updater screen (the "checking for updates" status
  # UI right after gamescope starts) takes a 16:9 background via
  # STEAM_UPDATEUI_PNG_BACKGROUND. Jovian's updater.splash options only
  # offer Valve/Jovian artwork; this replaces it with the stylix
  # wallpaper treated like the SDDM greeter (blur + base00 darken).
  # With no plymouth (boot.nix), this screen is the boot splash: the
  # first light after the black VT, already inside gamescope's HDR
  # output, and the greeter matches on exit-to-desktop.
  wallpaper =
    if (config ? stylix) && (config.stylix.enable or false)
    then config.stylix.image or null
    else null;
  colors = config.lib.stylix.colors.withHashtag;

  # 16:9 center-crop mirrors what jovian-updater-logo-helper produces at
  # runtime from the display canvas; Steam scales it to the output.
  steamSplash = pkgs.runCommand "steam-updater-splash.png" {
    nativeBuildInputs = [pkgs.imagemagick];
  } ''
    magick ${wallpaper} \
      -resize 2560x1440^ -gravity center -extent 2560x1440 \
      -blur 0x32 \
      -fill '${colors.base00}' -colorize 35% \
      png:$out
  '';
in {
  config = lib.mkIf (config.gaming.enable && wallpaper != null) {
    # "vendor" is updater.nix's off-switch: no logo-helper service, no
    # competing STEAM_UPDATEUI_PNG_BACKGROUND export.
    jovian.steam.updater.splash = "vendor";

    environment.etc."xdg/gamescope-session/environment".text = lib.mkAfter ''
      export STEAM_UPDATEUI_PNG_BACKGROUND="${steamSplash}"
    '';
  };
}
