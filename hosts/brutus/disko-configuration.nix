{...}: {
  disko.devices = {
    disk.usb1 = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions.root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/usb1";
          };
        };
      };
    };

    disk.usb2 = {
      device = "/dev/sdb";
      type = "disk";
      content = {
        type = "gpt";
        partitions.root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/usb2";
          };
        };
      };
    };
  };
}
