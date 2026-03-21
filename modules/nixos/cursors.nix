{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;

  themedCursors = pkgs.capitaine-cursors.overrideAttrs (old: {
    pname = "capitaine-cursors-stylix";

    postPatch =
      old.postPatch
      + ''
        find src/svg/dark -name '*.svg' -exec sed -i \
          -e 's/#fff"/#${colors.base00}"/g' \
          -e 's/#1a1a1a/#${colors.base04}/g' \
          {} +
      '';

    buildPhase = ''
      HOME="$NIX_BUILD_ROOT" ./build.sh --max-dpi xhd --type dark
    '';

    installPhase = ''
      install -dm 0755 "$out/share/icons/Capitaine Cursors"
      cp -pr dist/dark/* "$out/share/icons/Capitaine Cursors/"
    '';
  });
in {
  config = lib.mkIf config.stylix.enable {
    stylix.cursor = {
      name = "Capitaine Cursors";
      package = themedCursors;
      size = 18;
    };
  };
}
