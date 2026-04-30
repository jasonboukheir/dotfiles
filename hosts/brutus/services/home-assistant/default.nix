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
  auth_oidc = pkgs.home-assistant-custom-components.auth_oidc.overridePythonAttrs (old: {
    version = "1.0.2";
    src = pkgs.fetchFromGitHub {
      owner = "christiaangoossens";
      repo = "hass-oidc-auth";
      tag = "v1.0.2";
      hash = "sha256-ZYJD0PVh2E07cdY1a7uxSxdooAMz78HwJpwr4uWofZM=";
    };
    dependencies = with pkgs.python3Packages; [
      aiofiles
      bcrypt
      jinja2
      joserfc
    ];
  });
in {
  sunnycareboo.ports.allocate.home-assistant = lib.mkIf cfg.enable 8123;
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
      auth_oidc
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
        server_port = config.sunnycareboo.ports.values.home-assistant;
        trusted_proxies = ["::1"];
        use_x_forwarded_for = true;
      };
      recorder.db_url = "postgresql://@/hass";

      auth_oidc = {
        client_id = oidcCfg.settings.id;
        discovery_url = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
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
    proxyPass = "http://[::1]:${toString cfg.config.http.server_port}";
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
