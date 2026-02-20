{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
in {
  config = lib.mkIf (cfg.enable && cfg.pim == "evolution") {
    programs.evolution = {
      enable = true;
    };
    services.gnome.evolution-data-server = {
      enable = true;
    };
  };
}
