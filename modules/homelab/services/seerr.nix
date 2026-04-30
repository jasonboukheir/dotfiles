{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  homelabCfg = config.homelab.services.seer;
  cfg = config.services.jellyseerr;
in {
  config = lib.mkMerge [
    {
      homelab.services.seer = {
        isExternal = true;
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    }
    (lib.mkIf homelabCfg.enable {
      services.jellyseerr = {
        enable = true;
        package = pkgs-unstable.seerr;
      };
    })
  ];
}
