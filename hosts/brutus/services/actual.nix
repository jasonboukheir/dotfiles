{
  config,
  lib,
  ...
}: let
  cfg = config.services.actual;
  port = 5007;
in {
  services.actual = {
    enable = true;
    settings = {
      port = port;
    };
  };
  sunnycareboo.services.budget = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
  };
}
