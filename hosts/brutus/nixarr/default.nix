{
  lib,
  config,
  ...
}: let
  dataDir = "/var/lib/nixarr";
  globals = config.util-nixarr.globals;
  jellyfinPort = 8096;
  transmissionPort = 9091;
  cfg = config.nixarr;
in {
  imports = [
    ./audiobookshelfFixes.nix
    ./transmissionPortForwarding.nix
  ];
  age.secrets.nixarr-wgconf = {
    file = ../secrets/nixarr-wgconf.age;
    owner = globals.libraryOwner.user;
    group = globals.libraryOwner.group;
  };
  nixarr = {
    enable = config.services.brutus.enable;

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

    audiobookshelf = {
      enable = true;
      openFirewall = false;
    };
    jellyfin = {
      enable = true;
      openFirewall = false;
    };

    bazarr = {
      enable = true;
      openFirewall = false;
    };
    lidarr = {
      enable = true;
      openFirewall = false;
    };
    prowlarr = {
      enable = true;
      openFirewall = false;
    };
    radarr = {
      enable = true;
      openFirewall = false;
    };
    readarr = {
      enable = true;
      openFirewall = false;
    };
    sonarr = {
      enable = true;
      openFirewall = false;
    };
    jellyseerr = {
      enable = true;
      openFirewall = false;
    };
  };

  sunnycareboo.services = lib.mkIf config.nixarr.enable {
    transmission = lib.mkIf config.nixarr.transmission.enable {
      enable = true;
      proxyPass = "http://localhost:${toString transmissionPort}";
    };
    audiobookshelf = lib.mkIf config.nixarr.audiobookshelf.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.audiobookshelf.port}";
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

  fileSystems."${cfg.mediaDir}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/ssd_pool"
    ];
    device = "/ssd_pool/var/lib/nixarr";
    fsType = "none";
    options = ["bind"];
  };
}
