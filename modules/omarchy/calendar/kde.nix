{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
in {
  config = lib.mkIf (cfg.enable && cfg.pim == "kde") {
    programs.kde-pim = {
      enable = true;
      merkuro = true;
    };
    omarchy.defaultApps = {
      calendar = lib.mkDefault "merkuro-calendar";
      contacts = lib.mkDefault "merkuro-contact";
      reminders = lib.mkDefault "merkuro-calendar";
    };
  };
}
