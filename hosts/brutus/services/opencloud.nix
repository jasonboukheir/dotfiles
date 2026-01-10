{
  lib,
  config,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.opencloud;
  domain = config.sunnycareboo.services.cloud.domain;
  url = "https://${domain}";
  oidc_domain = config.sunnycareboo.services.id.domain;
  oidc_url = "https://${oidc_domain}";
in {
  services.opencloud = {
    enable = config.services.brutus.enable;

    url = url;
    address = "127.0.0.1";
    port = 9200;
    stateDir = "/var/lib/opencloud";

    package = pkgs-unstable.opencloud;
    webPackage = pkgs-unstable.opencloud.web;
    idpWebPackage = pkgs-unstable.opencloud.idp-web;

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
    csp = {
      enable = true;
      directives = {
        additionalConnectSrc = [oidc_url];
        additionalScriptSrc = [oidc_url];
      };
    };
    radicale.enable = true;
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
    };
  };

  sunnycareboo.services.cloud = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "https://localhost:${toString cfg.port}";
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
