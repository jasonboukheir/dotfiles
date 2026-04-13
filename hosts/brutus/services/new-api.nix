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
    credentials = {
      SESSION_SECRET = config.age.secrets."new-api/sessionSecret".path;
    };
  };

  age.secrets."new-api/sessionSecret" = lib.mkIf cfg.enable {
    file = ../secrets/new-api/sessionSecret.age;
  };

  sunnycareboo.services.llm = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://${cfg.host}:${toString cfg.port}";
  };
}
