{...}: {
  nixarr = {
    enable = true;

    vpn = {
      enable = true;
      wgConf = "/var/lib/secrets/nixarr/wg.conf";
    };

    transmission = {
      enable = true;
      flood.enable = true;
      vpn.enable = true;
      peerPort = 51820;
    };

    jellyfin.enable = true;

    bazarr.enable = true;
    lidarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = true;
    sonarr.enable = true;
    jellyseerr.enable = true;
  };
}
