{...}: let
  dataDir = "/usb1/nixarr";
in {
  imports = [
    ./transmissionPortForwarding.nix
  ];
  nixarr = {
    enable = true;

    mediaDir = "${dataDir}";
    stateDir = "${dataDir}/.state/nixarr";

    vpn = {
      enable = true;
      wgConf = "/var/lib/secrets/nixarr/wg.conf";
    };

    transmission = {
      enable = true;
      flood.enable = true;
      vpn.enable = true;
      extraSettings = {
        rpc-host-whitelist = "transmission.sunnycareboo.com";
      };
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
