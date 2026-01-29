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
  oidcWebCfg = config.services.pocket-id.ensureClients.opencloud-web;
in {
  services.opencloud = {
    enable = true;

    url = url;
    address = "0.0.0.0";
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
    environment = {
      "OC_INSECURE" = "true";
      "INSECURE" = "true";
      "INITIAL_ADMIN_PASSWORD" = "admin";
      "OC_DOMAIN" = config.sunnycareboo.services.cloud.domain;
      "PROXY_TLS" = "false";

      # oidc
      "OC_ADMIN_USER_ID" = "";
      "OC_OIDC_CLIENT_ID" = oidcWebCfg.settings.id;
      "OC_OIDC_ISSUER" = oidc_url;
      "WEB_OPTION_ACCOUNT_EDIT_LINK_HREF" = "${oidc_url}/settings/account";
      "OC_EXCLUDE_RUN_SERVICES" = "idp";
      "GRAPH_USERNAME_MATCH" = "none";
      "GRAPH_ASSIGN_DEFAULT_USER_ROLE" = "false";
    };
  };

  sunnycareboo = lib.mkIf cfg.enable {
    services.cloud = {
      enable = true;
      proxyPass = "http://localhost:${toString cfg.port}";
      extraConfig = ''
        # Increase max upload size (required for Tus — without this, uploads over 1 MB fail)
        client_max_body_size 10M;

        # Disable buffering - essential for SSE
        proxy_buffering off;
        proxy_request_buffering off;

        # Extend timeouts for long connections
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        keepalive_requests 100000;
        keepalive_timeout 5m;
        http2_max_concurrent_streams 512;

        # Prevent nginx from trying other upstreams
        proxy_next_upstream off;
      '';
    };
    wellKnown.webdav = domain;
  };

  fileSystems."${cfg.stateDir}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/ssd_pool"
    ];
    device = "/ssd_pool/var/lib/opencloud";
    fsType = "none";
    options = ["bind"];
  };

  services.pocket-id.ensureClients = lib.mkIf cfg.enable {
    opencloud-web = {
      logo = ./opencloud-light.svg;
      darkLogo = ./opencloud-dark.svg;
      dependentServices = [config.systemd.services.opencloud.name];
      settings = {
        name = "Open Cloud Web";
        isPublic = true;
        launchURL = url;
        callbackURLs = [
          url
          "${url}/oidc-callback.html"
          "${url}/oidc-silent-redirect.html"
        ];
      };
    };

    opencloud-android = {
      logo = ./opencloud-light.svg;
      darkLogo = ./opencloud-dark.svg;
      dependentServices = [config.systemd.services.opencloud.name];
      settings = {
        id = "OpenCloudAndroid";
        name = "Open Cloud Android";
        isPublic = true;
        launchURL = "oc://android.opencloud.eu";
        callbackURLs = [
          "oc://android.opencloud.eu"
        ];
      };
    };

    opencloud-ios = {
      logo = ./opencloud-light.svg;
      darkLogo = ./opencloud-dark.svg;
      dependentServices = [config.systemd.services.opencloud.name];
      settings = {
        id = "OpenCloudIOS";
        name = "Open Cloud iOS";
        isPublic = true;
        launchURL = "oc://ios.opencloud.eu";
        callbackURLs = [
          "oc://ios.opencloud.eu"
        ];
      };
    };

    opencloud-desktop = {
      logo = ./opencloud-light.svg;
      darkLogo = ./opencloud-dark.svg;
      dependentServices = [config.systemd.services.opencloud.name];
      settings = {
        id = "OpenCloudDesktop";
        name = "Open Cloud Desktop";
        isPublic = true;
        launchURL = null;
        callbackURLs = [
          "https://127.0.0.1"
          "http://localhost"
        ];
      };
    };
  };
}
