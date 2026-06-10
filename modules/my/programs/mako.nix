{
  lib,
  pkgs,
}: let
  iniFormat = pkgs.formats.ini {};
  iniAtom = iniFormat.lib.types.atom;

  formatValue = v:
    if lib.isBool v
    then lib.boolToString v
    else toString v;

  # Mirrors home-manager's services.mako generator (modules/services/mako.nix):
  # flat keys render as global `key=value` lines, attrset values as
  # `[criteria]` sections.
  renderConfig = settings: let
    globals = lib.filterAttrs (_: v: !lib.isAttrs v) settings;
    sections = lib.filterAttrs (_: lib.isAttrs) settings;
    renderLines = attrs: lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${formatValue v}") attrs);
    renderSection = name: attrs: "\n[${name}]\n" + renderLines attrs;
  in
    renderLines globals
    + lib.concatStrings (lib.mapAttrsToList renderSection sections)
    + "\n";

  # The base16 mapping of stylix's mako target (modules/mako/hm.nix at the
  # pinned stylix-nixos-unstable rev), reproduced for the wrapper.
  themedSettings = theme: let
    c = theme.colors;
    alpha = lib.fixedWidthString 2 "0" (lib.toHexString (builtins.ceil ((theme.opacity.popups or 1.0) * 255)));
    background = "#${c.base00}${alpha}";
    text = "#${c.base05}";
  in
    lib.optionalAttrs (theme.fonts ? sansSerif) {
      font = "${theme.fonts.sansSerif.name} ${toString theme.fonts.sizes.popups}";
    }
    // {
      background-color = background;
      border-color = "#${c.base0D}";
      text-color = text;
      progress-color = "over #${c.base02}";
      "urgency=low" = {
        background-color = background;
        border-color = "#${c.base03}";
        text-color = text;
      };
      "urgency=critical" = {
        background-color = background;
        border-color = "#${c.base08}";
        text-color = text;
      };
    };

  activationFiles = [
    "share/dbus-1/services/fr.emersion.mako.service"
    "share/systemd/user/mako.service"
    "lib/systemd/user/mako.service"
  ];
in {
  name = "mako";
  defaultPackage = "mako";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [iniAtom (lib.types.attrsOf iniAtom)]);
      default = {};
      example = {
        anchor = "top-right";
        default-timeout = 5000;
        "urgency=critical" = {border-color = "#ff0000";};
      };
      description = ''
        mako configuration baked into the wrapper via `--config`. Serialized
        like home-manager's `services.mako.settings`: flat keys become global
        options, attrset values become `[criteria]` sections (see mako(5)).
        When stylix theming is on, the base16 palette and fonts populate
        mako's color/font keys; these `settings` win per-key on conflicts.
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
    finalSettings =
      lib.recursiveUpdate
      (lib.optionalAttrs (theme != null) (themedSettings theme))
      cfg.settings;
    configFile = pkgs.writeText "mako-config" (renderConfig finalSettings);
    wrapped = pkgs.mkWrapped {
      pkg = cfg.package;
      name = "mako";
      flags = lib.optionals (finalSettings != {}) ["--config" "${configFile}"];
    };
  in
    # dbus can activate org.freedesktop.Notifications before any systemd unit
    # runs, and mako's shipped activation files Exec the unwrapped binary,
    # bypassing the baked config. symlinkJoin keeps the first colliding path
    # (pkg comes first), so mkWrapped's extraMerge cannot shadow them; rewrite
    # them in place to point at this wrapper instead.
    wrapped.overrideAttrs (old: {
      buildCommand =
        old.buildCommand
        + ''
          for service in ${toString activationFiles}; do
            [ -L "$out/$service" ] || continue
            shipped=$(readlink -f "$out/$service")
            rm "$out/$service"
            sed "s|${cfg.package}/bin|$out/bin|g" "$shipped" > "$out/$service"
          done
        '';
    });
}
