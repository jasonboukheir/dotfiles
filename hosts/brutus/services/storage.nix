{
  config,
  lib,
  ...
}: {
  fileSystems = lib.mkMerge [
    (lib.mkIf config.homelab.services.photos.enable {
      "${config.services.immich.mediaLocation}" = {
        depends = [
          "/"
          "/ssd_pool"
        ];
        device = "/ssd_pool/var/lib/immich";
        fsType = "none";
        options = ["bind"];
      };
    })
    (lib.mkIf config.homelab.services.cloud.enable {
      "${config.services.opencloud.stateDir}" = {
        depends = [
          "/"
          "/ssd_pool"
        ];
        device = "/ssd_pool/var/lib/opencloud";
        fsType = "none";
        options = ["bind"];
      };
    })
    (lib.mkIf config.homelab.services.git.enable {
      "${config.services.forgejo.stateDir}" = {
        depends = [
          "/"
          "/ssd_pool"
        ];
        device = "/ssd_pool/var/lib/forgejo";
        fsType = "none";
        options = ["bind"];
      };
    })
  ];
}
