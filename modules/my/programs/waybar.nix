{
  lib,
  pkgs,
}: let
  jsonFormat = pkgs.formats.json {};

  # Theming prelude ported from stylix's waybar home-manager target (with its
  # default knobs: font=monospace, addCss=true, back colors off) so the wrapper
  # looks identical to the HM-stylix setup it replaces:
  # https://github.com/nix-community/stylix/blob/a378e4c09031fb15a4d65da88aa628f71fc52f6b/modules/waybar/hm.nix
  basePaddingSelectors = [
    "#wireplumber, #pulseaudio, #sndio"
    "#wireplumber.muted, #pulseaudio.muted, #sndio.muted"
    "#upower, #battery"
    "#upower.charging, #battery.Charging"
    "#network"
    "#network.disconnected"
    "#user"
    "#clock"
    "#backlight"
    "#cpu"
    "#disk"
    "#idle_inhibitor"
    "#temperature"
    "#mpd"
    "#language"
    "#keyboard-state"
    "#memory"
    "#window"
    "#bluetooth"
    "#bluetooth.disabled"
  ];

  basePadding = lib.concatMapStrings (selector: ''
    ${selector} {
      padding: 0 5px;
    }
  '')
  basePaddingSelectors;

  workspaceButtons = place: ''
    .modules-${place} #workspaces button {
        border-bottom: 3px solid transparent;
    }
    .modules-${place} #workspaces button.focused,
    .modules-${place} #workspaces button.active {
        border-bottom: 3px solid @base05;
    }

    .modules-${place} #workspaces button.urgent {
        border-bottom: 3px solid @base08;
        background-color: @base08;
        color: @base00;
    }
  '';

  themedStyle = theme: let
    colors = lib.mapAttrs (_: hex: "#${hex}") theme.colors;
    defineColors =
      lib.concatMapStrings
      (slot: "@define-color ${slot} ${colors.${slot}};\n")
      (lib.attrNames colors);
  in
    ''
      window#waybar, tooltip {
          background: alpha(@base00, ${toString (theme.opacity.desktop or 1.0)});
      }
      * {
          font-family: "${theme.fonts.monospace.name or "DejaVu Sans Mono"}";
          font-size: ${toString (theme.fonts.sizes.desktop or 10)}pt;
      }
    ''
    + defineColors
    + ''
      window#waybar, tooltip {
          color: @base05;
      }

      tooltip {
          border-color: @base0D;
      }

      tooltip label {
          color: @base05;
      }
    ''
    + basePadding
    + lib.concatMapStrings workspaceButtons ["left" "center" "right"];
in {
  name = "waybar";
  defaultPackage = "waybar";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = lib.types.listOf jsonFormat.type;
      default = [];
      example = lib.literalExpression ''
        [
          {
            layer = "top";
            modules-center = ["clock"];
          }
        ]
      '';
      description = ''
        List of bar configurations (waybar's JSON config, see
        <https://github.com/Alexays/Waybar/wiki/Configuration>) baked into the
        wrapper and loaded with waybar's `-c` flag.
      '';
    };

    style = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        GTK CSS stylesheet baked into the wrapper and loaded with waybar's `-s`
        flag. When stylix theming is on, a prelude with the base16 palette as
        `@define-color` variables plus stylix's waybar base styling is
        prepended, so these lines can reference `@base00`..`@base0F` and win on
        conflicts.
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    theme ? null,
    ...
  }: let
    style = lib.optionalString (theme != null) (themedStyle theme) + cfg.style;
    configFile = jsonFormat.generate "waybar-config.json" cfg.settings;
    styleFile = pkgs.writeText "waybar-style.css" style;
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "waybar";
      flags =
        lib.optionals (cfg.settings != []) ["-c" "${configFile}"]
        ++ lib.optionals (style != "") ["-s" "${styleFile}"];
    };
}
