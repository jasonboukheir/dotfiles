{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
  colors = config.lib.stylix.colors;
  catppuccinSrc = inputs.catppuccin-steam-deck;

  themeName = "Stylix";

  rgbCsv = slot:
    "${toString colors."${slot}-rgb-r"}, "
    + "${toString colors."${slot}-rgb-g"}, "
    + "${toString colors."${slot}-rgb-b"}";

  # Catppuccin's selector library reads its palette out of `--ctp-*`
  # custom properties. Their upstream flavor files (mocha.css, latte.css,
  # …) populate those vars from a fixed palette; we instead populate
  # them from the active Stylix base16 scheme so the theme follows
  # whichever scheme stylix is currently rendering. Slot mapping below
  # follows base16 lightness ordering — Catppuccin's `crust < mantle
  # < base < surface0..2 < overlay0..2 < subtext0..1 < text` collapses
  # against base16's coarser `base00..base07` greys (we don't have a
  # tone darker than base00), and the accents map by hue.
  paletteCss = ''
    :root {
      --ctp-base: #${colors.base00};
      --ctp-mantle: #${colors.base01};
      --ctp-crust: #${colors.base00};

      --ctp-surface0: #${colors.base02};
      --ctp-surface1: #${colors.base02};
      --ctp-surface2: #${colors.base03};

      --ctp-overlay0: #${colors.base03};
      --ctp-overlay1: #${colors.base04};
      --ctp-overlay2: #${colors.base04};

      --ctp-subtext0: #${colors.base04};
      --ctp-subtext1: #${colors.base05};
      --ctp-text: #${colors.base05};

      --ctp-rosewater: #${colors.base06};
      --ctp-flamingo: #${colors.base08};
      --ctp-mauve: #${colors.base0E};
      --ctp-red: #${colors.base08};
      --ctp-peach: #${colors.base09};
      --ctp-yellow: #${colors.base0A};
      --ctp-green: #${colors.base0B};
      --ctp-teal: #${colors.base0C};
      --ctp-sky: #${colors.base0C};
      --ctp-sapphire: #${colors.base0C};
      --ctp-blue: #${colors.base0D};
      --ctp-lavender: #${colors.base0D};

      --ctp-accent-color: var(--stylix-base0D);

      --ctp-base-rgb: ${rgbCsv "base00"};
      --ctp-crust-rgb: ${rgbCsv "base00"};
      --ctp-surface0-rgb: ${rgbCsv "base02"};

      /* Catppuccin's SVG-recolor filter chains are precomputed per
         palette and can't be derived from arbitrary base16 hex at
         eval time — so monochrome icons keep their default fill.
         Acceptable for v1; revisit if specific glyphs look broken. */
      --ctp-base-filter: none;
      --ctp-mantle-filter: none;
      --ctp-red-filter: none;
      --ctp-text-filter: none;

      --ctp-blur: 10px;
      /* Leading `, ` is intentional — shared.css concatenates this
         into `rgba(<rgb-triplet><opacity>)` argument lists. */
      --ctp-opacity: , 0.8;

      /* Stylix base16 slots, exposed so future host-local tweaks can
         reference them by base16 name without re-templating. */
      --stylix-base00: #${colors.base00};
      --stylix-base01: #${colors.base01};
      --stylix-base02: #${colors.base02};
      --stylix-base03: #${colors.base03};
      --stylix-base04: #${colors.base04};
      --stylix-base05: #${colors.base05};
      --stylix-base06: #${colors.base06};
      --stylix-base07: #${colors.base07};
      --stylix-base08: #${colors.base08};
      --stylix-base09: #${colors.base09};
      --stylix-base0A: #${colors.base0A};
      --stylix-base0B: #${colors.base0B};
      --stylix-base0C: #${colors.base0C};
      --stylix-base0D: #${colors.base0D};
      --stylix-base0E: #${colors.base0E};
      --stylix-base0F: #${colors.base0F};
    }
  '';

  # `target` is a free-text category that just controls how the theme is
  # filed in the CSS Loader picker. `inject` is the actual mount-point
  # map — its keys are window-target identifiers documented at
  # https://docs.deckthemes.com/CSSLoader/Features/ . `bigpicture`
  # covers the BPM main window (home, library, store, settings, game
  # details) and `bigpictureoverlay` covers the Steam button menu +
  # Quick Access panel which render in a separate CEF window.
  #
  # `dependencies` declares an install-time prerequisite the CSS Loader
  # store should fetch alongside this theme. Catppuccin and most
  # palette-driven themes depend on "Focus Highlight Color" because
  # Valve's gamepad focus ring is layered on shared DOM the third-party
  # theme owns; declaring the dep means the ring follows our accent.
  themeJson = builtins.toJSON {
    name = themeName;
    author = "stylix (derived from catppuccin/steam-deck)";
    version = "1.0.0";
    description = "Catppuccin Steam Deck CSS, re-palettized from the active Stylix base16 scheme.";
    manifest_version = 8;
    target = "System-Wide";
    inject = {
      "colors.css" = ["bigpicture" "bigpictureoverlay"];
    };
    dependencies = {
      "Focus Highlight Color" = {
        "Round Compatibility" = "No";
      };
    };
  };

  colorsCss = pkgs.runCommand "stylix-steam-colors.css" {} ''
    cat ${pkgs.writeText "palette.css" paletteCss} \
        ${catppuccinSrc}/src/shared.css \
      > $out
  '';

  themePkg = pkgs.runCommand "stylix-steam-theme" {} ''
    install -Dm644 ${pkgs.writeText "theme.json" themeJson} $out/theme.json
    install -Dm644 ${colorsCss} $out/colors.css
  '';
in {
  options.gaming.steamTheme.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.jovian.decky-loader.enable;
    defaultText = lib.literalExpression "config.jovian.decky-loader.enable";
    description = ''
      Generate a CSS Loader theme directory by re-palettizing the
      upstream catppuccin/steam-deck selector library (`shared.css`)
      against the active Stylix base16 scheme. Refresh upstream with
      `nix flake update catppuccin-steam-deck` inside `./nixos`.
      Requires jovian.decky-loader.enable. CSS Loader itself still
      has to be installed once interactively from the Decky store
      inside Big Picture — see
      https://github.com/jasonboukheir/nix-config/issues/29 Phase 2
      for the rationale (no nix-packaged build yet).
    '';
  };

  config = lib.mkIf (cfg.steamTheme.enable && config.stylix.enable) {
    # The theme directory itself has to be writable: CSS Loader persists
    # the enabled/preset state to <theme>/config_USER.json on every
    # toggle, and an EROFS there silently reverts the toggle on the
    # next Refresh. So the directory is a regular dir owned by the
    # Steam user, and only the immutable payload files are symlinked
    # into the Nix store. The `r` rule evicts the legacy whole-dir
    # symlink left by earlier revisions; it's a no-op once the path
    # is a populated directory (tmpfiles refuses to `r` non-empty
    # dirs), so it won't clobber CSS Loader's persisted state. The
    # dir name is intentionally non-conflicting with anything the
    # user could install via the CSS Loader store UI (which would
    # land under .../themes/<store-name>/) so the two paths can't
    # fight.
    systemd.tmpfiles.settings."10-stylix-steam-theme" = {
      "${config.jovian.decky-loader.stateDir}/themes/${themeName}" = {
        r = {};
        d = {
          mode = "0755";
          user = cfg.user;
          group = cfg.user;
        };
      };
      "${config.jovian.decky-loader.stateDir}/themes/${themeName}/theme.json"."L+" = {
        argument = "${themePkg}/theme.json";
      };
      "${config.jovian.decky-loader.stateDir}/themes/${themeName}/colors.css"."L+" = {
        argument = "${themePkg}/colors.css";
      };
    };
  };
}
