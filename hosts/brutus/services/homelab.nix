{
  lib,
  config,
  ...
}: let
  cfg = config.homelab;
in {
  age.secrets."acme/env" = lib.mkIf cfg.enable {
    file = ../secrets/acme/env.age;
  };
  security.acme.defaults = lib.mkIf cfg.enable {
    dnsResolver = "1.1.1.1:53";
    dnsProvider = "cloudflare";
    environmentFile = config.age.secrets."acme/env".path;
  };
  homelab.enable = true;
  homelab.domain = "sunnycareboo.com";
}
