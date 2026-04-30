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
    ./lidarr.nix
    ./transmissionPortForwarding.nix
  ];
  age.secrets."nixarr/wgconf" = {
    file = ../secrets/nixarr/wgconf.age;
    owner = globals.libraryOwner.user;
    group = globals.libraryOwner.group;
  };
  nixarr = {
    enable = true;

    mediaDir = "${dataDir}";
    stateDir = "${dataDir}/.state/nixarr";

    vpn = {
      enable = true;
      wgConf = config.age.secrets."nixarr/wgconf".path;
    };

    transmission = {
      enable = true;
      flood.enable = true;
      peerPort = 44176;
      vpn.enable = true;
      extraSettings = {
        rpc-host-whitelist = config.homelab.services.transmission.domain;
      };
      privateTrackers.cross-seed = {
        enable = false;
        indexIds = [5];
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
    sonarr = {
      enable = true;
      openFirewall = false;
    };
  };

  homelab.ports.allocate = lib.mkIf cfg.enable {
    transmission-rpc = lib.mkIf cfg.transmission.enable transmissionPort;
    transmission-peer = lib.mkIf cfg.transmission.enable cfg.transmission.peerPort;
    jellyfin = lib.mkIf cfg.jellyfin.enable jellyfinPort;
    audiobookshelf = lib.mkIf cfg.audiobookshelf.enable config.services.audiobookshelf.port;
    bazarr = lib.mkIf cfg.bazarr.enable config.services.bazarr.listenPort;
    sonarr = lib.mkIf cfg.sonarr.enable config.services.sonarr.settings.server.port;
    radarr = lib.mkIf cfg.radarr.enable config.services.radarr.settings.server.port;
    prowlarr = lib.mkIf cfg.prowlarr.enable config.services.prowlarr.settings.server.port;
    lidarr = lib.mkIf cfg.lidarr.enable config.services.lidarr.settings.server.port;
  };

  homelab.services = lib.mkIf config.nixarr.enable {
    transmission = lib.mkIf config.nixarr.transmission.enable {
      enable = true;
      proxyPass = "http://127.0.0.1:${toString transmissionPort}";
    };
    audiobookshelf = lib.mkIf config.nixarr.audiobookshelf.enable {
      enable = true;
      isExternal = true;
      proxyPass = "http://localhost:${toString config.nixarr.audiobookshelf.port}";
    };
    jellyfin = lib.mkIf config.nixarr.jellyfin.enable {
      enable = true;
      isExternal = true;
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
    sonarr = lib.mkIf config.nixarr.sonarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.sonarr.port}";
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
