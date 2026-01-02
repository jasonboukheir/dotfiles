{
  config,
  lib,
  ...
}: let
  # Access the nixarr configuration variables
  nixarr = config.nixarr;
  cfg = config.nixarr.audiobookshelf;
in {
  # Only apply this if both nixarr and audiobookshelf are enabled
  config = lib.mkIf (nixarr.enable && cfg.enable) {
    systemd.services.audiobookshelf = {
      serviceConfig = {
        # This appends your media directory to the existing ReadWritePaths.
        # It uses the 'mediaDir' variable defined in your nixarr config.
        ReadWritePaths = [
          nixarr.mediaDir
        ];
      };
    };
  };
}
