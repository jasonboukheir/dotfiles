{config, ...}: let
  dataDir = "/usb1/nixarr";
  globals = config.util-nixarr.globals;
in {
  imports = [
    ./transmissionPortForwarding.nix
  ];
  age.secrets.nixarr-wgconf = {
    file = ../secrets/nixarr-wgconf.age;
    owner = globals.libraryOwner.user;
    group = globals.libraryOwner.group;
  };
  nixarr = {
    enable = true;

    mediaDir = "${dataDir}";
    stateDir = "${dataDir}/.state/nixarr";

    vpn = {
      enable = true;
      wgConf = config.age.secrets.nixarr-wgconf.path;
    };

    transmission = {
      enable = true;
      flood.enable = true;
      peerPort = 44176;
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
