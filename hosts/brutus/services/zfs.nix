{...}: let
  adminEmail = "jasonbk@sunnycareboo.com";
in {
  # 26.11 flips the default to false; pin true to keep this headless box
  # booting unattended after an unclean shutdown (the dual-import data-loss
  # risk false guards against does not apply to a single-machine local pool).
  boot.zfs.forceImportRoot = true;

  services.zfs.autoScrub = {
    enable = true;
    interval = "*-*-01 03:00:00";
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
