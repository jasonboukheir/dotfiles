{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    my.mako.enable = lib.mkDefault true;

    my.mako.settings = lib.mapAttrs (_: lib.mkDefault) {
      width = 420;
      height = 110;
      padding = "10";
      margin = "10";
      border-size = 2;
      border-radius = 0;

      anchor = "top-right";
      layer = "overlay";

      default-timeout = 5000;
      ignore-timeout = false;
      max-visible = 5;
      sort = "-time";

      group-by = "app-name";

      actions = true;

      format = "<b>%s</b>\\n%b";
      markup = true;
    };

    systemd.user.services.mako = {
      description = "Lightweight Wayland notification daemon";
      documentation = ["man:mako(1)"];
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = lib.getExe config.my.mako.finalPackage;
        ExecReload = "${lib.getExe' config.my.mako.finalPackage "makoctl"} reload";
      };
    };
  };
}
