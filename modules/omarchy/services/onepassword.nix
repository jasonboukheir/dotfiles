# Parity with the omarchy home-manager _1password autostart unit. The HM
# unit gated on HM's programs._1password.enable; the system-level analog
# for the GUI is programs._1password-gui, and its (possibly host-wrapped)
# package supplies the binary.
{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.omarchy.enable && config.programs._1password-gui.enable) {
    systemd.user.services._1password = {
      description = "1Password GUI (silent autostart)";
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig = {
        ExecStart = "${lib.getExe' config.programs._1password-gui.package "1password"} --silent";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
