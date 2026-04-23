{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.home-assistant;
  oidcCfg = config.services.pocket-id.ensureClients.home-assistant;
  domain = config.sunnycareboo.services.home.domain;
  url = "https://${domain}";
  port = 8123;
in {
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
        server_port = port;
        trusted_proxies = ["::1"];
        use_x_forwarded_for = true;
      };
      recorder.db_url = "postgresql://@/hass";

      auth_oidc = {
        client_id = oidcCfg.settings.id;
        discovery_url = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
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

      "automation ui" = "!include automations.yaml";
      "scene ui" = "!include scenes.yaml";
      "script ui" = "!include scripts.yaml";
    };
  };

  services.pocket-id.ensureClients.home-assistant = lib.mkIf cfg.enable {
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

  sunnycareboo.services.home = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://[::1]:${toString port}";
    extraConfig = ''
      proxy_buffering off;
    '';
  };

  services.postgresql = lib.mkIf cfg.enable {
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = ["hass"];
  };
}
