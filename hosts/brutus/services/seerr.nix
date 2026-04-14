{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.jellyseerr;
in {
  services.jellyseerr = {
    enable = true;
    package = pkgs-unstable.seerr;
  };

  sunnycareboo.services.seer = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://localhost:${toString cfg.port}";
  };
}
