{
  config,
  lib,
  pkgs,
  systemConfig,
  ...
}: let
  cfg = systemConfig.omarchy;

  terminalAppConfig = lib.concatMapStringsSep "\n\n" (app: ''
    [${app}]

    [${app}:cmd]
    c = C-S-c
    v = C-S-v
  '') cfg.macKeybindings.terminalApps;
in {
  config = lib.mkIf (cfg.enable && cfg.macKeybindings.enable) {
    xdg.configFile."keyd/app.conf".text = terminalAppConfig;

    systemd.user.services.keyd-application-mapper = {
      Unit = {
        Description = "keyd application-level key remapping";
        After = ["graphical-session.target"];
      };
      Install.WantedBy = ["graphical-session.target"];
      Service = {
        ExecStart = "${pkgs.keyd}/bin/keyd-application-mapper";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
