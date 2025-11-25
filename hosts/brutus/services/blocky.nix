{
  config,
  lib,
  ...
}: let
  cfg = config.services.blocky;
in {
  services.blocky = {
    enable = true;
    settings = {
      ports = {
        http = 1501;
      };
    };
  };

  sunnycareboo.services.blocky = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString cfg.settings.ports.http}";
  };
}
