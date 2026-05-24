{
  config,
  lib,
  pkgs,
  ...
}: let
  # See modules/omarchy/home-manager/hyprland/default.nix for why the
  # whole stack pins this to hyprland-session.target instead of the
  # graphical-session.target default.
  sessionTarget = config.wayland.systemd.target;
in {
  systemd.user.services._1password = lib.mkIf (config.omarchy.enable && config.programs._1password.enable) {
    Unit = {
      Description = "1Password GUI (silent autostart)";
      After = [sessionTarget];
      PartOf = [sessionTarget];
    };
    Service = {
      ExecStart = "${pkgs._1password-gui}/bin/1password --silent";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [sessionTarget];
  };
}
