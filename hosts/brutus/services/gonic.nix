{
  config,
  lib,
  ...
}: let
  musicDir = "${config.nixarr.mediaDir}/library/music";
  gonicDataDir = "/var/lib/gonic";
  cfg = config.services.gonic;
in {
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

  sunnycareboo.services.gonic = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://${cfg.settings.listen-addr}";
  };
}
