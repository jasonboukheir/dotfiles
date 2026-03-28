{config, ...}: {
  age.secrets."power/ups/user/pw".file = ../secrets/power/ups/user/pw.age;
  power.ups = {
    enable = true;
    mode = "standalone";

    # 1. Define the UPS Device (The Hardware)
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

    # 2. Define the User (The Software Access)
    # NUT requires a local user to monitor the device.
    users.nut = {
      passwordFile = config.age.secrets."power/ups/user/pw".path;
      upsmon = "primary"; # This machine is in charge of the UPS
    };

    # 3. Define the Monitor (The Logic)
    # This watches the UPS defined above ('tripplite@localhost')
    upsmon.monitor.tripplite = {
      system = "tripplite@localhost";
      powerValue = 1;
      user = "nut";
      passwordFile = config.age.secrets."power/ups/user/pw".path;
      type = "primary";
    };
  };
}
