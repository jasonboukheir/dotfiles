{
  config,
  lib,
  ...
}: let
  musicDir = "${config.nixarr.mediaDir}/library/music";
  podcastDir = "${config.nixarr.mediaDir}/library/podcasts";
  gonicDataDir = "/var/lib/gonic";
  cfg = config.services.gonic;
in {
  services.gonic = {
    enable = true;
    settings = {
      music-path = [musicDir];
      podcast-path = podcastDir;
      playlists-path = "${gonicDataDir}/playlists";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${gonicDataDir}/playlists 0755 root root -"
  ];

  systemd.services.gonic.serviceConfig = {
    BindPaths = lib.mkForce [
      cfg.settings.playlists-path
      cfg.settings.cache-path
    ];
    BindReadOnlyPaths = lib.mkAfter [podcastDir];
  };

  sunnycareboo.services.gonic = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://${cfg.settings.listen-addr}";
  };
}
