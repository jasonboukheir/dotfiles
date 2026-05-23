{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;

  themedCursors = pkgs.bibata-cursors.overrideAttrs (old: {
    pname = "bibata-cursors-stylix";

    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.librsvg];

    bitmaps = null;

    buildPhase = ''
      runHook preBuild

      mkdir -p themed-svg bitmaps/Bibata-Modern-Stylix
      cp -rL svg/modern/. themed-svg/

      find themed-svg -name '*.svg' -exec sed -i \
        -e 's/#00FF00/#${colors.base04}/gi' \
        -e 's/#0000FF/#${colors.base00}/gi' \
        -e 's/#FF0000/#${colors.base04}/gi' \
        {} +

      find themed-svg -name '*.svg' -print0 | \
        xargs -0 -n 1 -P "''${NIX_BUILD_CORES:-1}" sh -c \
          'rsvg-convert -w 256 -h 256 -o "bitmaps/Bibata-Modern-Stylix/$(basename "$1" .svg).png" "$1"' _

      ctgen configs/normal/x.build.toml -p x11 \
        -d bitmaps/Bibata-Modern-Stylix \
        -n 'Bibata-Modern-Stylix' \
        -c 'Bibata cursors themed with stylix base16 colors'

      runHook postBuild
    '';
  });
in {
  config = lib.mkIf config.stylix.enable {
    stylix.cursor = {
      name = "Bibata-Modern-Stylix";
      package = themedCursors;
      size = 24;
    };
  };
}
