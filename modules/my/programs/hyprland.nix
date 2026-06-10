{
  lib,
  pkgs,
}: let
  inherit (import ../lib/hyprland {inherit lib;}) toHyprlua settingsType;

  # The same slots stylix's hyprland HM target paints (modules/hyprland/hm.nix
  # at the pinned stylix rev), in the lua-config shape ({config = …}).
  themedSettings = theme: let
    c = theme.colors;
    rgb = color: "rgb(${color})";
  in {
    config = {
      decoration.shadow.color = "rgba(${c.base00}99)";
      general = {
        "col.active_border" = rgb c.base0D;
        "col.inactive_border" = rgb c.base03;
      };
      group = {
        "col.border_inactive" = rgb c.base03;
        "col.border_active" = rgb c.base0D;
        "col.border_locked_active" = rgb c.base0C;
        groupbar = {
          text_color = rgb c.base05;
          "col.active" = rgb c.base0D;
          "col.inactive" = rgb c.base03;
        };
      };
      misc.background_color = rgb c.base00;
    };
  };
in {
  name = "hyprland";
  defaultPackage = "hyprland";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = settingsType;
      default = {};
      example = {
        terminal = {_var = "ghostty";};
        config.general.gaps_in = 5;
        bind = [
          {
            _args = [
              "SUPER + return"
              (lib.generators.mkLuaInline ''hl.dsp.exec_cmd(terminal)'')
            ];
          }
        ];
      };
      description = ''
        Hyprland Lua config (`hyprland.lua`) baked into this wrapper's
        session entry. Follows home-manager's `configType = "lua"`
        conventions: each attribute is an `hl.<name>(…)` call (lists make
        one call per element), `_args` lists make multi-argument calls,
        `_var` attrs become Lua `local` bindings, and
        `lib.generators.mkLuaInline` values are raw Lua expressions.

        When stylix theming is on, the base16 palette populates the
        border/group/shadow/background color slots (the same ones stylix's
        HM hyprland target painted); these `settings` win on conflicts.
      '';
    };
  };

  settingsDefaults = {theme ? null, ...}:
    lib.optionalAttrs (theme != null) (themedSettings theme);

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    configFile = pkgs.writeText "hyprland.lua" (toHyprlua cfg.settings);
    hasSettings = cfg.settings != {} && cfg.settings != null;

    # Sessions launch Hyprland through the absolute `Exec=…/start-hyprland`
    # baked into the package's hyprland.desktop (and the shipped
    # hyprland-uwsm.desktop resolves that same entry), not via PATH — so the
    # config rides the session entry's argv, not a binary wrapper.
    # start-hyprland forwards everything after `--` to Hyprland.
    final = pkgs.symlinkJoin {
      name = "hyprland-wrapped";
      paths = [cfg.package];
      postBuild = lib.optionalString hasSettings ''
        session=$out/share/wayland-sessions/hyprland.desktop
        real=$(readlink -f "$session")
        grep -q '^Exec=.*start-hyprland$' "$real" || {
          echo "hyprland.desktop no longer execs start-hyprland; the --config injection needs a new home" >&2
          exit 1
        }
        rm "$session"
        sed 's|^Exec=\(.*\)$|Exec=\1 -- --config ${configFile}|' "$real" > "$session"
      '';
      passthru =
        (cfg.package.passthru or {})
        // {
          unwrapped = cfg.package;
          inherit (cfg.package) version;
          inherit configFile;
          # programs.hyprland's package apply (genFinalPackage) probes
          # functionArgs of .override for an enableXWayland arg; a no-arg
          # lambda makes it leave the wrapper untouched — the underlying
          # hyprland already builds with XWayland.
          override = _args: final;
        };
      meta = {inherit (cfg.package.meta) mainProgram;};
    };
  in
    final;
}
