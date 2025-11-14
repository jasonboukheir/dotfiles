{
  config,
  lib,
  ...
}: let
  cfg = config.services.searx;
  domain = "search.sunnycareboo.com";
in {
  age.secrets = {
    "searx/env.age" = {file = ../secrets/searx/env.age;};
  };

  services.searx = {
    enable = true;
    redisCreateLocally = true;
    configureNginx = true;
    domain = domain;
    # this is broken right now for Uwsgi: https://github.com/NixOS/nixpkgs/issues/292652
    environmentFile = config.age.secrets."searx/env.age".path;
    settings = {
      server.secret_key = "$SEARX_SECRET_KEY";
      search = {
        formats = ["html" "json"];
      };
    };
  };

  services.nginx.virtualHosts."${domain}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
  };
}
