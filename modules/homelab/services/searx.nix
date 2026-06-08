{
  config,
  lib,
  ...
}: let
  homelabCfg = config.homelab.services.search;
  domain = config.homelab.services.search.domain;
  port = config.homelab.ports.values.searx;
in {
  config = lib.mkMerge [
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.searx = 3300;

      age.secrets."searx/env.age".file = config.homelab.secretsDir + /searx/env.age;

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
              disabled = true;
            }
            # scraping endpoint hits 429s under OWUI fan-out; route web search
            # through the paid API instead.
            {
              name = "brave";
              disabled = true;
            }
            {
              name = "braveapi";
              shortcut = "brapi";
              api_key = "$BRAVE_API_KEY";
              inactive = false;
            }
          ];
        };
        uwsgiConfig = {
          http = ":${toString port}";
        };
      };
    })
  ];
}
