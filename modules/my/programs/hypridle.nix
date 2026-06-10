{
  lib,
  pkgs,
}: let
  settingsType = with lib.types;
    nullOr (oneOf [
      bool
      int
      float
      str
      path
      (attrsOf settingsType)
      (listOf settingsType)
    ])
    // {description = "hyprlang value (attrsets are sections; lists of attrsets repeat a section)";};

  # Minimal hyprlang renderer mirroring home-manager's
  # lib.hm.generators.toHyprconf (not available to pure defs, and nixpkgs lib
  # ships no hyprlang generator): `$`-prefixed variables first, attrset values
  # as `name { … }` sections, lists of attrsets as repeated sections, lists of
  # scalars as duplicate keys. Duplicated in ./hyprlock.nix — defs are pure
  # standalone files.
  toHyprlang = let
    render = indent: attrs: let
      isSection = v: lib.isAttrs v || (lib.isList v && v != [] && lib.all lib.isAttrs v);
      variables = lib.filterAttrs (n: _: lib.hasPrefix "$" n) attrs;
      rest = removeAttrs attrs (lib.attrNames variables);
      sections = lib.filterAttrs (_: isSection) rest;
      fields = lib.filterAttrs (n: v: !isSection v) rest;
      mkSection = name: value:
        if lib.isList value
        then lib.concatMapStringsSep "\n" (mkSection name) value
        else "${indent}${name} {\n${render "  ${indent}" value}${indent}}\n";
      mkFields = lib.generators.toKeyValue {
        listsAsDuplicateKeys = true;
        inherit indent;
      };
    in
      mkFields variables
      + lib.concatStringsSep "\n" (lib.mapAttrsToList mkSection sections)
      + mkFields fields;
  in
    render "";
in {
  name = "hypridle";
  defaultPackage = "hypridle";

  options = {
    settings = lib.mkOption {
      type = settingsType;
      default = {};
      example = {
        general.lock_cmd = "pidof hyprlock || hyprlock";
        listener = [
          {
            timeout = 600;
            on-timeout = "loginctl lock-session";
          }
        ];
      };
      description = ''
        hypridle config baked into this wrapper and loaded via `--config`.
        Repeated `listener` blocks are a list of attrsets. Commands in
        `lock_cmd`/`on-timeout`/… resolve from the daemon's PATH — the unit
        that runs this wrapper decides what that contains (see the omarchy
        hypridle user service, which pins hyprlock to the my.* wrapper).
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    configFile = pkgs.writeText "hypridle.conf" (toHyprlang cfg.settings);

    # TODO: drop once nixpkgs ships hypridle > 0.1.7 — up to 0.1.7 an explicit
    # --config still aborts unless a config also exists in HOME/XDG/etc/hypr.
    # https://github.com/hyprwm/hypridle/commit/f158b2fe9293f9b25f681b8e46d84674e7bc7f01
    explicitConfigFix = pkgs.fetchpatch {
      url = "https://github.com/hyprwm/hypridle/commit/f158b2fe9293f9b25f681b8e46d84674e7bc7f01.patch";
      hash = "sha256-Qpg/xI+u5ACKuThl9rei8jufz6XCRuEvYShiF/bRTDU=";
    };
    package =
      if lib.versionAtLeast cfg.package.version "0.1.8"
      then cfg.package
      else
        cfg.package.overrideAttrs (prev: {
          patches = (prev.patches or []) ++ [explicitConfigFix];
        });
  in
    pkgs.mkWrapped {
      pkg = package;
      name = "hypridle";
      flags = lib.optionals (cfg.settings != {} && cfg.settings != null) ["--config" "${configFile}"];
    };
}
