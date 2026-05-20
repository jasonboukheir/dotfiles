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

  # `.well-known/matrix/*` lives on the apex so `@user:sunnycareboo.com`
  # IDs keep resolving even if synapse/MAS move URLs. Setting all four
  # here (rather than as side effects of individual service modules)
  # keeps the public Matrix discovery surface visible in one place; the
  # synapse and MAS modules just expose `.domain` outputs that this
  # block composes.
  homelab.wellKnown.matrix = {
    server = "${config.homelab.services.synapse.domain}:443";
    client = "https://${config.homelab.services.synapse.domain}";
    issuer = "https://${config.homelab.services.matrix-auth.domain}/";
    account = "https://${config.homelab.services.matrix-auth.domain}/account";
  };

  homelab.services = {
    ai.enable = true;
    matrix-auth.enable = true;
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
    ntfy.enable = true;
    photos.enable = true;
    radicale.enable = true;
    search.enable = true;
    seer.enable = true;
  };
}
