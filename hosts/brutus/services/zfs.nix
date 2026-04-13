{...}: let
  adminEmail = "jasonbk@sunnycareboo.com";
in {
  services.zfs.autoScrub = {
    enable = true;
    interval = "*-*-* 03:00:00";
    pools = ["ssd_pool" "ext_pool"];
  };

  services.zfs.zed = {
    enableMail = true;
    settings = {
      ZED_EMAIL_ADDR = [adminEmail];
      ZED_NOTIFY_VERBOSE = true;
    };
  };
}
