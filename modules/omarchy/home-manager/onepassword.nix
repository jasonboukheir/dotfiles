{
  config,
  lib,
  pkgs,
  ...
}: {
  systemd.user.services._1password = lib.mkIf (config.omarchy.enable && config.programs._1password.enable) {
    Unit = {
      Description = "1Password GUI (silent autostart)";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs._1password-gui}/bin/1password --silent";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
