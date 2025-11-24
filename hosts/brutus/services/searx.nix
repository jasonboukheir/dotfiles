{
  config,
  lib,
  ...
}: let
  cfg = config.services.searx;
  domain = config.sunnycareboo.services.search.domain;
in {
  sunnycareboo = lib.mkIf cfg.enable {
    enable = true;
    services.search = {
      enable = true;
      manageVirtualHost = false;
    };
  };

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
}
