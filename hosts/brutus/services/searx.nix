{
  config,
  lib,
  ...
}: let
  cfg = config.services.searx;
  domain = config.homelab.services.search.domain;
  port = config.homelab.ports.values.searx;
in {
  homelab.ports.allocate.searx = lib.mkIf cfg.enable 3300;
  homelab.services.search = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
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
      engines = [
        {
          name = "wikidata";
          disabled = "True";
        }
        # scraping endpoint hits 429s under OWUI fan-out; route web search
        # through the paid API instead.
        {
          name = "brave";
          disabled = "True";
        }
        {
          name = "braveapi";
          engine = "braveapi";
          shortcut = "brapi";
          api_key = "$BRAVE_API_KEY";
        }
      ];
    };
    uwsgiConfig = {
      http = ":${toString port}";
    };
  };
}
