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
  homelab.secretsDir = ../secrets;
  homelab.services = {
    ai.enable = true;
    budget.enable = true;
    certs.enable = true;
    chat.enable = true;
    synapse.enable = true;
    cloud.enable = true;
    code.enable = true;
    gonic.enable = true;
    headscale.enable = true;
    home.enable = true;
    id.enable = true;
    lldap.enable = true;
    meals.enable = true;
    memos.enable = true;
    photos.enable = true;
    radicale.enable = true;
    search.enable = true;
    seer.enable = true;
  };
}
