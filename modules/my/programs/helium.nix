# pkgs.helium comes from helium-flake's overlay (only applied on hosts that
# enable this tool). Helium is ungoogled-chromium-based: the per-profile
# "External Extensions" + external_update_url install path is stripped and is a
# no-op. The channel Helium actually honors is a Chromium managed policy
# (ExtensionInstallForcelist) in /etc/chromium/policies/managed, which
# force-installs and pins the listed extensions. `extensions` below feeds that
# policy via the framework's `etc` hook — system state, never user-profile state.
{
  lib,
  pkgs,
}: {
  name = "helium";
  defaultPackage = "helium";

  options = {
    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["aeblfdkhhhdcdjpifhhbdiojplfjncoa"];
      description = ''
        Chrome Web Store extension IDs to force-install through the
        ExtensionInstallForcelist managed policy. Each entry is auto-enabled and
        cannot be removed from within Helium. An entry may carry an explicit
        update URL as `<id>;<update_url>`; a bare id uses the default store URL.
      '';
    };
  };

  etc = {cfg, ...}:
    lib.optionalAttrs (cfg.extensions != []) {
      "chromium/policies/managed/helium-extensions.json".text = builtins.toJSON {
        ExtensionInstallForcelist = cfg.extensions;
      };
    };

  build = {
    cfg,
    ...
  }:
    cfg.package;
}
