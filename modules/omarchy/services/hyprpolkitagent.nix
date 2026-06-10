# Parity with home-manager's services.hyprpolkitagent unit; the agent
# binary ships in libexec, not bin.
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    systemd.user.services.hyprpolkitagent = {
      description = "Hyprland PolicyKit Agent";
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig.ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
    };
  };
}
