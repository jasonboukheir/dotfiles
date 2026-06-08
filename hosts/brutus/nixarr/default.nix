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

  # Interactive searches fan out across rate-limited indexers and can run for
  # several minutes; keep nginx from dropping the connection at the 60s default.
  arrSearchTimeout = "600s";
in {
  imports = [
    ./arrApi.nix
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

  # Offload Jellyfin transcoding to the Intel Arc (renderD128) via QuickSync.
  # nixarr's jellyfin module only sets enable/dirs but delegates to the
  # upstream services.jellyfin module, so these options merge onto the same
  # service. The Arc is shared with vllm-xpu (gpuMemoryUtilization 0.85, ~27GB
  # of 32GB), so cap concurrent transcodes to fit the remaining VRAM headroom.
  users.users.${config.services.jellyfin.user}.extraGroups = ["render" "video"];
  services.jellyfin = lib.mkIf cfg.jellyfin.enable {
    forceEncodingConfig = true;
    hardwareAcceleration = {
      enable = true;
      type = "qsv";
      device = "/dev/dri/renderD128";
    };
    transcoding = {
      enableHardwareEncoding = true;
      enableIntelLowPowerEncoding = true;
      enableToneMapping = true;
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        vp9 = true;
        av1 = true;
      };
      hardwareEncodingCodecs.hevc = true;
      maxConcurrentStreams = 2;
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
      # nginx buffers the response to a temp file by default and throttles
      # reads from Jellyfin while buffers drain, which stalls high-bitrate 4K
      # direct play (plays a few seconds, then freezes). Jellyfin 10.11's
      # chunked direct-play delivery makes this severe.
      # https://github.com/jellyfin/jellyfin/issues/15237
      extraConfig = ''
        proxy_buffering off;
      '';
    };
    bazarr = lib.mkIf config.nixarr.bazarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.bazarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    lidarr = lib.mkIf config.nixarr.lidarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.lidarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    prowlarr = lib.mkIf config.nixarr.prowlarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.prowlarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    radarr = lib.mkIf config.nixarr.radarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.radarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    sonarr = lib.mkIf config.nixarr.sonarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.sonarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
  };

  fileSystems."${cfg.mediaDir}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/hdd_pool1"
    ];
    device = "/hdd_pool1/var/lib/nixarr";
    fsType = "none";
    options = ["bind"];
  };

  # nixarr (and the upstream nixos transmission module) declare
  # RequiresMountsFor for the default /var/lib/transmission paths, but we
  # relocate everything under cfg.mediaDir (a bind mount on top of a ZFS
  # dataset). Without a mount dep on the real path, a nixos-rebuild can
  # unmount /var/lib/nixarr, restart transmission against the empty rootfs
  # mountpoint, and then remount /var/lib/nixarr on top -- leaving
  # transmission in a stale mount namespace with no visible state. Bind the
  # service to the actual mount so it waits for the dataset.
  systemd.services.transmission.unitConfig = lib.mkIf cfg.transmission.enable {
    RequiresMountsFor = cfg.mediaDir;
  };
}
