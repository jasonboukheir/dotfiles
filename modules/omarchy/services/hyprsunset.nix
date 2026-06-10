# Parity with home-manager's services.hyprsunset unit (sans
# ConditionEnvironment — omarchy.sessionTarget already gates on
# WAYLAND_DISPLAY being in the user manager, see ../config.nix).
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    systemd.user.services.hyprsunset = {
      description = "hyprsunset - Hyprland's blue-light filter";
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig = {
        ExecStart = lib.getExe pkgs.hyprsunset;
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
