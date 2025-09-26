{...}: {
  disko.devices = {
    disk.usb1 = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions.zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "zroot";
          };
        };
      };
    };

    disk.usb2 = {
      device = "/dev/sdb";
      type = "disk";
      content = {
        type = "gpt";
        partitions.zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "zroot";
          };
        };
      };
    };

    zpool.zroot = {
      type = "zpool";
      mode = "mirror";
      datasets = {
        "root" = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };
        "root/zfs_fs" = {
          type = "zfs_fs";
          mountpoint = "/zroot";
          options."com.sun:auto-snapshot" = "true";
        };
      };
    };
  };
}
