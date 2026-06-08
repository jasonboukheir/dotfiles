{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  homelabCfg = config.homelab.services.seer;
  cfg = config.services.seerr;
in {
  config = lib.mkMerge [
    {
      homelab.services.seer = {
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    }
    (lib.mkIf homelabCfg.enable {
      services.seerr = {
        enable = true;
        package = pkgs-unstable.seerr;
      };
    })
  ];
}
