{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;

  themedCursors = pkgs.capitaine-cursors.overrideAttrs (old: {
    pname = "capitaine-cursors-stylix";

    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.librsvg];

    # Upstream build.sh shells out to inkscape per (svg × size), paying GTK
    # startup and emitting fontconfig warnings on every call. Swap in
    # rsvg-convert and parallelise across cores: ~5min build → ~1s.
    postPatch =
      old.postPatch
      + ''
        find src/svg/dark -name '*.svg' -exec sed -i \
          -e 's/#fff"/#${colors.base04}"/g' \
          -e 's/#1a1a1a/#${colors.base00}/g' \
          {} +

        renderOld=$'  for svg_file in "$SRC/svg/$variant"/*.svg; do\n   inkscape "''${INKSCAPE_OPTS[@]}" "$OUTPUT_DIR/$(basename "''${svg_file%.svg}").png" "$svg_file"\n  done'
        renderNew=$'  export size OUTPUT_DIR\n  printf "%s\\0" "$SRC/svg/$variant"/*.svg | xargs -0 -n 1 -P "''${NIX_BUILD_CORES:-1}" sh -c \'rsvg-convert -w "$size" -h "$size" -o "$OUTPUT_DIR/$(basename "''${1%.svg}").png" "$1"\' _'
        substituteInPlace build.sh --replace-fail "$renderOld" "$renderNew"

        substituteInPlace build.sh \
          --replace-fail '$(inkscape -V | cut -d'"'"' '"'"' -f2)' '1.0'
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
      size = 32;
    };
  };
}
