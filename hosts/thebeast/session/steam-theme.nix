{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;
  colors = config.lib.stylix.colors;

  themeName = "Stylix";

  # Limited to the System-Wide target plus the legacy `bigpicture` /
  # `QuickAccess` aliases that CSS Loader still honours on the
  # `steam -gamepadui` build, so the same stylesheet covers the home
  # grid, library, store, QAM panel, and lock screen in one drop.
  # CSS Loader scans theme.json's `inject` map at plugin startup and
  # picks themes up by directory scan, so a pure file-drop install is
  # sufficient — no runtime API call is needed.
  themeJson = builtins.toJSON {
    name = themeName;
    author = "stylix";
    version = "1.0.0";
    description = "Auto-generated from the active Stylix base16 scheme";
    manifest_version = 8;
    target = "System-Wide";
    inject = {
      "colors.css" = ["System-Wide"];
    };
  };

  # Stylix exposes a base16 attrset at config.lib.stylix.colors with
  # raw hex (no leading #). CSS Loader injects this stylesheet into
  # every GamepadUI document, so the strategy is: bind every base16
  # slot to a custom property, then re-point the small set of Valve
  # CSS variables that are documented as stable across client betas.
  # Mangled React class names (`.libraryhome_Container_xxxx`) rotate
  # every Steam beta and are deliberately not touched here — see
  # https://docs.deckthemes.com/CSSLoader/theming_step_by_step/
  colorsCss = ''
    :root {
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

      --main-bg-color: var(--stylix-base00);
      --main-bg-transparency: var(--stylix-base00);
      --main-editor-bg-color: var(--stylix-base00);
      --main-editor-fg-color: var(--stylix-base05);
      --main-text-color: var(--stylix-base05);
      --main-text-color-secondary: var(--stylix-base04);
      --main-text-color-muted: var(--stylix-base03);
      --main-accent-color: var(--stylix-base0D);
      --main-accent-color-hover: var(--stylix-base0E);
      --main-accent-color-active: var(--stylix-base08);
      --main-link-color: var(--stylix-base0D);
      --main-link-color-hover: var(--stylix-base0E);
      --header-bg-color: var(--stylix-base01);
      --header-fg-color: var(--stylix-base06);
      --tab-bar-bg-color: var(--stylix-base01);
      --tab-bar-fg-color: var(--stylix-base05);
      --tab-bar-fg-color-selected: var(--stylix-base07);
      --tab-bar-fg-color-hover: var(--stylix-base06);
      --tab-bar-focus-color: var(--stylix-base0D);
      --focus-ring-color: var(--stylix-base0D);
      --selection-bg-color: var(--stylix-base02);
      --selection-fg-color: var(--stylix-base07);
      --hover-bg-color: var(--stylix-base02);
      --button-bg-color: var(--stylix-base01);
      --button-fg-color: var(--stylix-base05);
      --button-bg-color-hover: var(--stylix-base02);
      --button-fg-color-hover: var(--stylix-base07);
      --notification-bg-color: var(--stylix-base01);
      --notification-fg-color: var(--stylix-base05);
      --notification-accent-color: var(--stylix-base0D);
      --qam-bg-color: var(--stylix-base01);
      --qam-fg-color: var(--stylix-base05);
      --qam-accent-color: var(--stylix-base0D);
    }

    body,
    html,
    .gamepadui_Root,
    .gamepadui_GamepadUIRoot,
    .basicuibody {
      background-color: var(--stylix-base00) !important;
      color: var(--stylix-base05) !important;
    }
  '';

  themePkg = pkgs.runCommand "stylix-steam-theme" {} ''
    install -Dm644 ${pkgs.writeText "theme.json" themeJson} $out/theme.json
    install -Dm644 ${pkgs.writeText "colors.css" colorsCss} $out/colors.css
  '';
in {
  options.gaming.steamTheme.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.jovian.decky-loader.enable;
    defaultText = lib.literalExpression "config.jovian.decky-loader.enable";
    description = ''
      Generate a CSS Loader theme directory from the active Stylix
      base16 scheme and drop it into Decky's themes path. Requires
      jovian.decky-loader.enable. CSS Loader itself still has to be
      installed once interactively from the Decky store inside Big
      Picture — see https://github.com/jasonboukheir/nix-config/issues/29
      Phase 2 for the rationale (no nix-packaged build yet).
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
