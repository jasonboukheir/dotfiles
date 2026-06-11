{
  lib,
  config,
  ...
}: let
  cfg = config.nixarr;
  jellyfinPort = 8096;
  transmissionPort = 9091;

  # Interactive searches fan out across rate-limited indexers and can run for
  # several minutes; keep nginx from dropping the connection at the 60s default.
  arrSearchTimeout = "600s";
in {
  # nixarr homelab-service wiring: which *arr/media services exist on the
  # homelab and how nginx proxies them. The backing flake input
  # (inputs.nixarr) is imported by ../default.nix; the host that runs these
  # services supplies the host-specific config — nixarr.enable, media/state
  # dirs, the VPN, Jellyfin hardware acceleration, the storage mounts and
  # secrets — in hosts/<host>/nixarr. `isExternal` lives in ../../registry.nix.
  imports = [
    ./arrApi.nix
    ./audiobookshelfFixes.nix
    ./lidarr.nix
    ./transmissionPortForwarding.nix
  ];

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

  homelab.services = lib.mkIf cfg.enable {
    transmission = lib.mkIf cfg.transmission.enable {
      enable = true;
      proxyPass = "http://127.0.0.1:${toString transmissionPort}";
    };
    audiobookshelf = lib.mkIf cfg.audiobookshelf.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.audiobookshelf.port}";
    };
    jellyfin = lib.mkIf cfg.jellyfin.enable {
      enable = true;
      proxyPass = "http://localhost:${toString jellyfinPort}";
      # Jellyfin 10.11's chunked direct-play delivery fetches the next chunk
      # at the last possible moment and can go quiet in between; the 60s
      # default proxy_read_timeout turns that pause into a killed connection
      # mid-playback. https://github.com/jellyfin/jellyfin/issues/15237
      proxyReadTimeout = "600s";
      # nginx buffers the response to a temp file by default and throttles
      # reads from Jellyfin while buffers drain, which stalls high-bitrate 4K
      # direct play (plays a few seconds, then freezes). Jellyfin 10.11's
      # chunked direct-play delivery makes this severe.
      # https://github.com/jellyfin/jellyfin/issues/15237
      extraConfig = ''
        proxy_buffering off;
      '';
    };
    bazarr = lib.mkIf cfg.bazarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.bazarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    lidarr = lib.mkIf cfg.lidarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.lidarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    prowlarr = lib.mkIf cfg.prowlarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.prowlarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    radarr = lib.mkIf cfg.radarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.radarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
    sonarr = lib.mkIf cfg.sonarr.enable {
      enable = true;
      proxyPass = "http://localhost:${toString config.nixarr.sonarr.port}";
      proxyReadTimeout = arrSearchTimeout;
    };
  };
}
