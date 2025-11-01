{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.opencloud;
  domain = "cloud.sunnycareboo.com";
  url = "https://${domain}";
  oidc_domain = "pocket-id.sunnycareboo.com";
  oidc_url = "https://${oidc_domain}";
  cspConfigFile =
    pkgs.writeText "opencloud-csp-config"
    (builtins.readFile ./csp.yaml);
in {
  # TODO: setup pocket-id as idp
  services.opencloud = {
    enable = true;
    url = url;
    address = "127.0.0.1";
    port = 9200;
    stateDir = "/var/lib/opencloud";

    settings = {
      proxy = {
        auto_provision_accounts = true;
        oidc = {
          rewrite_well_known = true;
        };
        role_assignment = {
          driver = "oidc";
          oidc_role_mapper = {
            role_claim = "opencloud_roles";
            role_mapping = [
              {
                role_name = "admin";
                claim_value = "admin";
              }
              {
                role_name = "spaceadmin";
                claim_value = "spaceadmin";
              }
              {
                role_name = "user";
                claim_value = "user";
              }
              {
                role_name = "guest";
                claim_value = "guest";
              }
            ];
          };
        };
      };
      web = {
        web = {
          config = {
            oidc = {
              scope = "openid profile email opencloud_roles";
            };
          };
        };
      };
    };
    environment = {
      "OC_INSECURE" = "true";
      "INSECURE" = "true";
      "INITIAL_ADMIN_PASSWORD" = "admin";

      # oidc
      "OC_ADMIN_USER_ID" = "";
      "OC_OIDC_CLIENT_ID" = "4c4ddfb4-b892-4563-9f7f-80cad38fd084";
      "OC_OIDC_ISSUER" = oidc_url;
      "WEB_OPTION_ACCOUNT_EDIT_LINK_HREF" = "${oidc_url}/settings/account";
      "OC_EXCLUDE_RUN_SERVICES" = "idp";
      "GRAPH_USERNAME_MATCH" = "none";
      "GRAPH_ASSIGN_DEFAULT_USER_ROLE" = "false";

      # csp settings
      "PROXY_CSP_CONFIG_FILE_LOCATION" = "${cspConfigFile}";
    };
  };

  services.nginx.virtualHosts."${domain}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
    locations."/" = {
      proxyPass = "https://localhost:${toString cfg.port}";
      proxyWebsockets = true;
    };
  };

  fileSystems."${cfg.stateDir}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/usb2"
    ];
    device = "/usb2/opencloud";
    fsType = "none";
    options = ["bind"];
  };
}
