{
  config,
  lib,
  ...
}: {
  age.secrets."power/ups/user/pw".file = ../secrets/power/ups/user/pw.age;
  power.ups = {
    enable = true;
    mode = "standalone";

    ups.tripplite = {
      driver = "usbhid-ups";
      port = "auto";
      description = "Tripp Lite OMNI1500LCDT";
      directives = [
        "vendorid = 09ae"
        "productid = 3016"
      ];
      maxStartDelay = null;
    };

    users.nut = {
      passwordFile = config.age.secrets."power/ups/user/pw".path;
      upsmon = "primary";
    };

    upsmon.monitor.tripplite = {
      system = "tripplite@localhost";
      powerValue = 1;
      user = "nut";
      passwordFile = config.age.secrets."power/ups/user/pw".path;
      type = "primary";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="09ae", ATTR{idProduct}=="3016", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/ups-tripplite"
  '';

  systemd.services.upsdrv = {
    after = lib.mkForce ["network.target" "dev-ups\\x2dtripplite.device"];
    wants = ["dev-ups\\x2dtripplite.device"];
  };

  systemd.services.upsd.after = lib.mkForce [
    "network.target"
    "upsdrv.service"
  ];

  systemd.services.upsmon.after = lib.mkForce [
    "network.target"
    "upsd.service"
  ];
}
