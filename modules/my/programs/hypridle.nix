{
  lib,
  pkgs,
}: let
  inherit (import ../lib/hyprland {inherit lib;}) toHyprlang settingsType;
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
