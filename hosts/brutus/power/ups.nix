{
  config,
  pkgs,
  ...
}: {
  age.secrets."power/ups/user/pw".file = ../secrets/power/ups/user/pw.age;
  power.ups = {
    enable = true;
    mode = "standalone";

    # 1. Define the UPS Device (The Hardware)
    ups.tripplite = {
      # The OMNI1500LCDT is a USB HID compliant device
      driver = "usbhid-ups";
      port = "auto";
      description = "Tripp Lite OMNI1500LCDT";
      # If you have USB connection issues, you can uncomment the pollinterval
      # directives = [ "pollinterval = 2" ];
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

    # 4. Shutdown Configuration
    # This command runs when the UPS reaches "Critical" (Low Battery) status.
    # NixOS defaults usually handle this well, but being explicit is good.
    upsmon.settings = {
      # The command to shut down the system
      SHUTDOWNCMD = "${pkgs.systemd}/bin/shutdown -h now";

      # How long to wait for the UPS to react to the kill-power command
      # before the system gives up and halts anyway.
      FINALDELAY = 5;
    };
  };
}
