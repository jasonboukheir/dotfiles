{pkgs, ...}: {
  # Enable Disko to manage the USB drives and generate fileSystems
  disko.enableConfig = true;

  # Enable ZFS support
  environment.systemPackages = with pkgs; [zfs];
  boot.supportedFilesystems = ["zfs"];
  services.zfs.autoScrub.enable = true; # Optional: Periodic data integrity checks
  services.zfs.autoSnapshot.enable = true; # Optional: Automatic snapshots

  disko.devices = {
    disk.usb1 = {
      device = "/dev/disk/by-id/usb-Samsung_PSSD_T7_Shield_S6SFNJ0W520633R-0:0";
      type = "disk";
      content = {
        type = "zfs";
        pool = "tank";
      };
    };

    disk.usb2 = {
      device = "/dev/disk/by-id/usb-Samsung_PSSD_T7_Shield_S6SFNJ0W520654H-0:0";
      type = "disk";
      content = {
        type = "zfs";
        pool = "tank";
      };
    };

    zpool.tank = {
      type = "zpool";
      mode = "stripe";
      rootFsType = "zfs";
      datasets = {
        "root" = {
          type = "zfs_fs";
          mountpoint = "/mnt/stripe";
          options = {
            atime = "off"; # Improve performance for USB drives
            compression = "lz4"; # Enable compression
          };
        };
      };
    };
  };
}
