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
      mountpoint = "/mnt/zroot";
      rootFsOptions = {
        compression = "zstd"; # Enable compression
        "com.sun:auto-snapshot" = "false";
      };
      postCreateHook = "zfs list -t snapshot -H -o name | grep -E '^zroot@blank$' || zfs snapshot zroot@blank";
    };
  };
}
