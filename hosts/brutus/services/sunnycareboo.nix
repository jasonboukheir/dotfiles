{lib, config, ...}:
let cfg = config.sunnycareboo;
  in{
  age.secrets."acme/env" = lib.mkIf cfg.enable {
    file = ../secrets/acme/env.age;
  };
  security.acme.defaults = lib.mkIf cfg.enable {
    dnsResolver = "1.1.1.1:53";
    dnsProvider = "cloudflare";
    environmentFile = config.age.secrets."acme/env".path;
  };
  sunnycareboo.enable = true;
  sunnycareboo.baseDomain = "sunnycareboo.com";
}
