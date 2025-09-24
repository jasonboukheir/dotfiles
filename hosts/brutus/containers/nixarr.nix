{inputs, ...}: {
  boot.enableContainers = true;
  containers.nixarr = {
    autoStart = true;
    privateNetwork = false;
    bindMounts = {
      "/var/lib" = {
        hostPath = "/mnt/zroot/nixarr/var/lib";
        isReadOnly = false;
      };
      "/data/media" = {
        hostPath = "/mnt/zroot/nixarr/media";
        isReadOnly = false;
      };
    };

    config = {config, ...}: {
      system.stateVersion = "25.11";
      imports = [
        inputs.nixarr.nixosModules.default
      ];
      nixarr = {
        enable = true;

        vpn = {
          enable = true;
          wgConf = "/var/lib/secrets/protonvpn/wg.conf";
        };

        jellyfin.enable = true;
        transmission = {
          enable = true;
          vpn.enable = true;
          peerPort = 51820;
        };

        bazarr.enable = true;
        lidarr.enable = true;
        prowlarr.enable = true;
        radarr.enable = true;
        readarr.enable = true;
        sonarr.enable = true;
        jellyseerr.enable = true;
      };
    };
  };
}
