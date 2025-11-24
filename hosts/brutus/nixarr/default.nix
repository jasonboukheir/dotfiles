{
  lib,
  config,
  ...
}: let
  dataDir = "/usb1/nixarr";
  globals = config.util-nixarr.globals;
  jellyfinPort = 8096;
  transmissionPort = 9091;
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
        rpc-host-whitelist = config.sunnycareboo.services.transmission.domain;
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

  sunnycareboo = lib.mkIf config.nixarr.enable {
    enable = true;
    services = {
      transmission = lib.mkIf config.nixarr.transmission.enable {
        enable = true;
        proxyPass = "http://localhost:${toString transmissionPort}";
      };
      jellyfin = lib.mkIf config.nixarr.jellyfin.enable {
        enable = true;
        proxyPass = "http://localhost:${toString jellyfinPort}";
      };
      bazarr = lib.mkIf config.nixarr.bazarr.enable {
        enable = true;
        proxyPass = "http://localhost:${toString config.nixarr.bazarr.port}";
      };
      lidarr = lib.mkIf config.nixarr.lidarr.enable {
        enable = true;
        proxyPass = "http://localhost:${toString config.nixarr.lidarr.port}";
      };
      prowlarr = lib.mkIf config.nixarr.prowlarr.enable {
        enable = true;
        proxyPass = "http://localhost:${toString config.nixarr.prowlarr.port}";
      };
      radarr = lib.mkIf config.nixarr.radarr.enable {
        enable = true;
        proxyPass = "http://localhost:${toString config.nixarr.radarr.port}";
      };
      readarr = lib.mkIf config.nixarr.readarr.enable {
        enable = true;
        proxyPass = "http://localhost:${toString config.nixarr.readarr.port}";
      };
      sonarr = lib.mkIf config.nixarr.sonarr.enable {
        enable = true;
        proxyPass = "http://localhost:${toString config.nixarr.sonarr.port}";
      };
      jellyseerr = lib.mkIf config.nixarr.jellyseerr.enable {
        enable = true;
        proxyPass = "http://localhost:${toString config.nixarr.jellyseerr.port}";
      };
    };
  };
}
