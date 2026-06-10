# Parity with home-manager's services.clipse unit. The client binary is
# also installed system-wide: the Hyprland clipboard binding opens the
# clipse TUI directly.
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    environment.systemPackages = [pkgs.clipse];

    systemd.user.services.clipse = {
      description = "Clipse listener";
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe pkgs.clipse} -listen";
      };
    };
  };
}
