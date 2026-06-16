{
  config,
  lib,
  ...
}: let
  # Service state relocated onto the SSD pool via bind mounts. Declared once
  # as data so the fileSystems entries and the tmpfiles ordering below stay in
  # sync.
  bindMounts = [
    {
      enable = config.homelab.services.photos.enable;
      target = config.services.immich.mediaLocation;
      device = "/ssd_pool/var/lib/immich";
    }
    {
      enable = config.homelab.services.cloud.enable;
      target = config.services.opencloud.stateDir;
      device = "/ssd_pool/var/lib/opencloud";
    }
    {
      enable = config.homelab.services.git.enable;
      target = config.services.forgejo.stateDir;
      device = "/ssd_pool/var/lib/forgejo";
    }
  ];
  active = builtins.filter (m: m.enable) bindMounts;
  targets = map (m: m.target) active;
in {
  fileSystems = builtins.listToAttrs (map (m: {
      name = m.target;
      value = {
        depends = [
          "/"
          "/ssd_pool"
        ];
        device = m.device;
        fsType = "none";
        options = ["bind"];
      };
    })
    active);

  # Order the switch-time tmpfiles run after these mounts. Both tmpfiles units
  # already order After=local-fs.target, which covers boot (fstab mounts are
  # part of local-fs.target). But `nixos-rebuild switch` starts a *newly
  # introduced* mount concurrently with systemd-tmpfiles-resetup, and
  # After=local-fs.target imposes no ordering against it — so tmpfiles creates
  # service state dirs (e.g. forgejo's custom/) on the bare mountpoint and the
  # mount then hides them. A hardened unit whose ReadWritePaths reference such a
  # not-yet-created subdir then dies at namespace setup (status 226/NAMESPACE).
  # RequiresMountsFor pulls in and orders after the specific mount units.
  systemd.services.systemd-tmpfiles-resetup =
    lib.mkIf (active != [])
    {unitConfig.RequiresMountsFor = targets;};
}
