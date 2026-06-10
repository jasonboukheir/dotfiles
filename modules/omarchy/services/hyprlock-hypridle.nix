# Native screen-lock stack: my.hyprlock (invoked by hypridle and
# `loginctl lock-session`, no daemon of its own) plus a hypridle user unit,
# replacing modules/omarchy/home-manager/{hyprlock,hypridle}.nix (issue #48).
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    my.hyprlock.enable = lib.mkDefault true;
    my.hyprlock.settings.general = {
      hide_cursor = lib.mkDefault true;
      grace = lib.mkDefault 2;
      no_fade_in = lib.mkDefault false;
    };

    my.hypridle.enable = lib.mkDefault true;
    my.hypridle.settings = {
      general = {
        lock_cmd = lib.mkDefault "pidof hyprlock || hyprlock";
        before_sleep_cmd = lib.mkDefault "loginctl lock-session";
        after_sleep_cmd = lib.mkDefault "hyprctl dispatch dpms on";
      };
      listener = lib.mkDefault [
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 1800;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on && brightnessctl -r";
        }
      ];
    };

    # What nixpkgs' programs.hyprlock module would set; without it PAM has no
    # hyprlock service and unlocking always fails.
    security.pam.services.hyprlock = {};

    systemd.user.services.hypridle = {
      description = "hypridle";
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
      # `path` becomes the unit's entire PATH, so it must carry everything the
      # configured lock/dpms commands shell out to — and pinning the my.*
      # hyprlock wrapper here is the point: lock_cmd can't resolve some other
      # hyprlock from the session environment.
      path = [
        config.my.hyprlock.finalPackage
        config.programs.hyprland.package
        pkgs.procps
        pkgs.systemd
        pkgs.brightnessctl
      ];
      serviceConfig = {
        ExecStart = lib.getExe config.my.hypridle.finalPackage;
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
