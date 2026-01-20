{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nixarr.lidarr;
in {
  config = lib.mkIf cfg.enable {
    systemd.services.lidarr = {
      path = with pkgs; [
        ffmpeg
      ];
    };
  };
}
