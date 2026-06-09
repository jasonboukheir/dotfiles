{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.home;
  cfg = config.services.home-assistant;
  oidcCfg = config.services.pocket-id.ensureClients.home-assistant;
  domain = config.homelab.services.home.domain;
  url = "https://${domain}";
in {
  config = lib.mkMerge [
    {
      homelab.services.home = {
        proxyPass = "http://[::1]:${toString cfg.config.http.server_port}";
        extraConfig = ''
          proxy_buffering off;
        '';
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.home-assistant = 8123;

      services.home-assistant = {
        enable = true;
        extraComponents = [
          "default_config"
          "esphome"
          "met"
          "radio_browser"
          "isal"

          "homekit"
          "homekit_controller"

          "matter"

          "mqtt"

          "ollama"
        ];
        customComponents = [
          pkgs.home-assistant-custom-components.auth_oidc
        ];
        extraPackages = ps: with ps; [psycopg2];
        config = {
          default_config = {};
          homeassistant = {
            name = "Home";
            unit_system = "us_customary";
            external_url = url;
          };
          http = {
            server_host = "::1";
            server_port = config.homelab.ports.values.home-assistant;
            trusted_proxies = ["::1"];
            use_x_forwarded_for = true;
          };
          recorder.db_url = "postgresql://@/hass";

          auth_oidc = {
            client_id = oidcCfg.settings.id;
            discovery_url = "https://${config.homelab.services.id.domain}/.well-known/openid-configuration";
            features = {
              automatic_user_linking = true;
              default_redirect = true;
              force_https = true;
            };
          };

          homekit = [
            {
              filter = {
                include_domains = [
                  "light"
                  "switch"
                  "climate"
                  "lock"
                  "cover"
                  "fan"
                  "media_player"
                  "sensor"
                ];
              };
            }
          ];
        };
      };

      services.pocket-id.ensureClients.home-assistant = {
        logo = ./home-assistant.svg;
        dependentServices = [config.systemd.services.home-assistant.name];
        settings = {
          name = "Home Assistant";
          launchURL = url;
          isPublic = true;
          callbackURLs = [
            "${url}/auth/oidc/callback"
          ];
        };
      };

      services.postgresql = {
        ensureUsers = [
          {
            name = "hass";
            ensureDBOwnership = true;
          }
        ];
        ensureDatabases = ["hass"];
      };
    })
  ];
}
