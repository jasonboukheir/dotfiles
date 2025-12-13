{
  lib,
  config,
  ...
}: let
  cfg = config.services.opencloud.radicale;
in {
  options.services.opencloud.radicale = {
    enable = lib.mkEnableOption "OpenCloud Radicale configuration";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5232;
      description = "Port that radicale is being served on";
    };
  };

  config = lib.mkIf cfg.enable {
    services.opencloud.settings.proxy.additional_policies = [
      {
        name = "default";
        routes = let
          routeSpecs = [
            {
              endpoint = "/caldav/";
              script = "/caldav";
            }
            {
              endpoint = "/.well-known/caldav";
              script = "/caldav";
            }
            {
              endpoint = "/carddav/";
              script = "/carddav";
            }
            {
              endpoint = "/.well-known/carddav";
              script = "/carddav";
            }
          ];
        in
          map (spec: {
            endpoint = spec.endpoint;
            backend = "http://localhost:${toString cfg.port}";
            remote_user_header = "X-Remote-User";
            skip_x_access_token = true;
            additional_headers = [
              {"X-Script-Name" = spec.script;}
            ];
          })
          routeSpecs;
      }
    ];

    services.radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [
            "0.0.0.0:${toString cfg.port}"
            "[::]:${toString cfg.port}"
          ];
        };
        auth = {
          type = "http_x_remote_user";
        };
        storage = {
          filesystem_folder = "/var/lib/radicale/collections";
          predefined_collections = builtins.toJSON {
            "def-addressbook" = {
              "D:displayname" = "Personal Address Book";
              tag = "VADDRESSBOOK";
            };
            "def-calendar" = {
              "C:supported-calendar-component-set" = "VEVENT,VJOURNAL,VTODO";
              "D:displayname" = "Personal Calendar";
              tag = "VCALENDAR";
            };
          };
        };
        web = {
          type = "none";
        };
      };
    };
  };
}
