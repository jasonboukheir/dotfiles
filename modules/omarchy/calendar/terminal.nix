{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
in {
  config = lib.mkIf (cfg.enable && cfg.pim == "terminal") {
    omarchy.defaultApps = {
      calendar = lib.mkDefault "ghostty -e khal interactive";
      contacts = lib.mkDefault "ghostty -e khard";
      reminders = lib.mkDefault "ghostty -e todoman";
    };
  };
}
