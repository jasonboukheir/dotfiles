# Native wallpaper daemon: my.hyprpaper bakes the stylix wallpaper behind
# --config, replacing the HM services.hyprpaper that stylix's hyprland HM
# target used to auto-enable (issue #48).
{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    # Without a wallpaper (or any explicit settings) hyprpaper has nothing
    # to display and would just crash-loop on its missing config.
    my.hyprpaper.enable = lib.mkDefault (config.my.hyprpaper.settings != {});

    systemd.user.services.hyprpaper = lib.mkIf config.my.hyprpaper.enable {
      description = "hyprpaper";
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig = {
        ExecStart = lib.getExe config.my.hyprpaper.finalPackage;
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
