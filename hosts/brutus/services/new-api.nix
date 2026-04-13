{
  lib,
  config,
  ...
}: let
  cfg = config.services.new-api;
  port = 3200;
in {
  services.new-api = {
    enable = true;
    port = port;
  };

  sunnycareboo.services.llm = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://${cfg.host}:${toString cfg.port}";
  };
}
