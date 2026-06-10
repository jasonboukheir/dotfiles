# Parity with home-manager's services.wl-clip-persist unit
# (clipboardType "regular", its default).
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    systemd.user.services.wl-clip-persist = {
      description = "Wayland clipboard persistence daemon";
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.wl-clip-persist} --clipboard regular";
        Restart = "on-failure";
      };
    };
  };
}
