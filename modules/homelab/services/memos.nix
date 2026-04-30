{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  homelabCfg = config.homelab.services.memos;
  cfg = config.services.memos;
in {
  config = lib.mkMerge [
    {
      homelab.services.memos = {
        isExternal = true;
        proxyPass = "http://localhost:${cfg.settings.MEMOS_PORT}";
      };
    }
    (lib.mkIf homelabCfg.enable {
      services.memos = {
        enable = true;
        package = pkgs-unstable.memos;
      };
    })
  ];
}
