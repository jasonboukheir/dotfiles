{
  lib,
  config,
  ...
}: let
  dataDir = "/var/lib/nixarr";
  globals = config.util-nixarr.globals;
  cfg = config.nixarr;
in {
  # Host-specific nixarr config: what brutus runs, where its media/state
  # live, the VPN, Jellyfin's Intel-Arc hardware acceleration, and the
  # storage mounts. The homelab-service wiring (proxyPass/ports/registry)
  # and the nixarr flake input live under modules/homelab/services/nixarr.
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

  fileSystems."${cfg.mediaDir}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/hdd_pool1"
    ];
    device = "/hdd_pool1/var/lib/nixarr";
    fsType = "none";
    options = ["bind"];
  };

  # nixarr (and the upstream nixos service modules) declare RequiresMountsFor
  # for the default /var/lib/<svc> paths, but we relocate everything under
  # cfg.mediaDir (a bind mount on top of a ZFS dataset). Without a mount dep on
  # the real path, a nixos-rebuild can unmount /var/lib/nixarr, restart a
  # service against the empty rootfs mountpoint, and then remount /var/lib/nixarr
  # on top -- leaving the service in a stale mount namespace with no visible
  # state, or writing to the dataset mid-(un)mount and corrupting its SQLite DB
  # (see issue #59: radarr Commands-table corruption). Bind every stateful
  # service to the actual mount so it waits for the dataset.
  systemd.services = let
    statefulServices = lib.filter (s: cfg.${s}.enable) [
      "transmission"
      "radarr"
      "sonarr"
      "lidarr"
      "prowlarr"
      "bazarr"
      "jellyfin"
      "audiobookshelf"
    ];
  in
    lib.mkIf cfg.enable (lib.genAttrs statefulServices (_: {
      unitConfig.RequiresMountsFor = cfg.mediaDir;
    }));
}
