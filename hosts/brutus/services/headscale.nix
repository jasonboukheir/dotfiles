{lib, config,...}: let
  cfg = config.services.headscale;
  domain = config.sunnycareboo.services.ts.domain;
  port = 3400;
in {
  services.headscale = {
    enable = true;
    port = port;
    settings = {
      oidc = {};
    };
  };
  sunnycareboo.services.ts = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
  };
}
