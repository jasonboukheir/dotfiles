{
  config,
  lib,
  ...
}: let
  homelabCfg = config.homelab.services.gonic;
  musicDir = "${config.nixarr.mediaDir}/library/music";
  gonicDataDir = "/var/lib/gonic";
  cfg = config.services.gonic;
in {
  config = lib.mkMerge [
    {
      homelab.services.gonic = {
        isExternal = true;
        proxyPass = "http://${cfg.settings.listen-addr}";
      };
    }
    (lib.mkIf homelabCfg.enable {
      services.gonic = {
        enable = true;
        settings = {
          music-path = [musicDir];
          podcast-path = "${gonicDataDir}/podcasts";
          playlists-path = "${gonicDataDir}/playlists";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${gonicDataDir}/playlists 0755 root root -"
        "d ${gonicDataDir}/podcasts 0755 root root -"
      ];
    })
  ];
}
