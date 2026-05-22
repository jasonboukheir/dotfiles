{
  config,
  lib,
  ...
}: let
  cfg = config.programs._1password-gui;
in {
  options.programs._1password-gui.customAllowedBrowsers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["helium" "librewolf"];
    description = ''
      Binary names of additional browsers to trust for 1Password's
      browser integration. Rendered into
      /etc/1password/custom_allowed_browsers, one name per line.

      See https://support.1password.com/getting-started-1password-linux/#integrate-with-other-browsers
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.customAllowedBrowsers != []) {
    environment.etc."1password/custom_allowed_browsers".text =
      lib.concatMapStrings (b: b + "\n") cfg.customAllowedBrowsers;
  };
}
