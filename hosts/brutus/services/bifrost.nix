{
  lib,
  config,
  ...
}: let
  cfg = config.services.bifrost;
  port = 3500;
in {
  services.bifrost = {
    enable = true;
    inherit port;
  };

  sunnycareboo.services.llm = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://${cfg.host}:${toString cfg.port}";
  };
}
