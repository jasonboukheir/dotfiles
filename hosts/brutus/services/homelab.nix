{
  lib,
  config,
  ...
}: let
  cfg = config.homelab;
  telegramSecretPath = ../secrets/mautrix-telegram/env.age;
  telegramSecretPresent = builtins.pathExists telegramSecretPath;
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
    # MSC4143 — pointing Element Call clients at the lk-jwt-service
    # endpoint of our matrix-rtc vhost. lk-jwt-service mints the JWT
    # the client then uses to dial the SFU advertised under it.
    rtcFoci = [
      {
        type = "livekit";
        livekit_service_url = "https://${config.homelab.services.matrix-rtc.domain}/livekit/jwt";
      }
    ];
  };

  homelab.services = {
    ai.enable = true;
    matrix-auth.enable = true;
    budget.enable = true;
    call.enable = true;
    certs.enable = true;
    chat.enable = true;
    matrix-rtc.enable = true;
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

  # Telegram is the only bridge that needs out-of-band creds (api_id +
  # api_hash from my.telegram.org); the others bootstrap via QR / OAuth
  # over Matrix. Hold the bridge in pending until the agenix file lands
  # so the rest of the host still evaluates on a fresh checkout.
  age.secrets."mautrix-telegram/env" = lib.mkIf (cfg.enable && telegramSecretPresent) {
    file = telegramSecretPath;
  };

  homelab.matrix-bridges = {
    discord.enable = true;
    telegram = {
      enable = telegramSecretPresent;
      environmentFile =
        if telegramSecretPresent
        then config.age.secrets."mautrix-telegram/env".path
        else null;
    };
    whatsapp.enable = true;
    signal.enable = true;
    gmessages.enable = true;
  };
}
