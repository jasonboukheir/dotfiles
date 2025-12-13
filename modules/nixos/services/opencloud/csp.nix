# csp-config.nix
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.opencloud.csp;
in {
  options.services.opencloud.csp = {
    enable = lib.mkEnableOption "OpenCloud CSP configuration";

    companionDomain = lib.mkOption {
      type = lib.types.str;
      default = "\${COMPANION_DOMAIN|companion.opencloud.test}";
      description = "Companion domain for CSP directives";
    };

    collaboraDomain = lib.mkOption {
      type = lib.types.str;
      default = "\${COLLABORA_DOMAIN|collabora.opencloud.test}";
      description = "Collabora domain for CSP directives";
    };

    directives = {
      additionalChildSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional child-src directives";
      };

      additionalConnectSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional connect-src directives";
      };

      additionalDefaultSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional default-src directives";
      };

      additionalFontSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional font-src directives";
      };

      additionalFrameAncestors = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional frame-ancestors directives";
      };

      additionalFrameSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional frame-src directives";
      };

      additionalImgSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional img-src directives";
      };

      additionalManifestSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional manifest-src directives";
      };

      additionalMediaSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional media-src directives";
      };

      additionalObjectSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional object-src directives";
      };

      additionalScriptSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional script-src directives";
      };

      additionalStyleSrc = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional style-src directives";
      };
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Generated CSP config file path";
    };
  };

  config = lib.mkIf cfg.enable {
    services.opencloud.csp.configFile = let
      cspConfig = {
        directives = {
          child-src =
            [
              "'self'"
            ]
            ++ cfg.directives.additionalChildSrc;

          connect-src =
            [
              "'self'"
              "blob:"
              "https://${cfg.companionDomain}/"
              "wss://${cfg.companionDomain}/"
              "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
              "https://update.opencloud.eu/"
            ]
            ++ cfg.directives.additionalConnectSrc;

          default-src =
            [
              "'none'"
            ]
            ++ cfg.directives.additionalDefaultSrc;

          font-src =
            [
              "'self'"
            ]
            ++ cfg.directives.additionalFontSrc;

          frame-ancestors =
            [
              "'self'"
            ]
            ++ cfg.directives.additionalFrameAncestors;

          frame-src =
            [
              "'self'"
              "blob:"
              "https://embed.diagrams.net/"
              "https://${cfg.collaboraDomain}/"
              "https://docs.opencloud.eu"
            ]
            ++ cfg.directives.additionalFrameSrc;

          img-src =
            [
              "'self'"
              "data:"
              "blob:"
              "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
              "https://${cfg.collaboraDomain}/"
            ]
            ++ cfg.directives.additionalImgSrc;

          manifest-src =
            [
              "'self'"
            ]
            ++ cfg.directives.additionalManifestSrc;

          media-src =
            [
              "'self'"
            ]
            ++ cfg.directives.additionalMediaSrc;

          object-src =
            [
              "'self'"
              "blob:"
            ]
            ++ cfg.directives.additionalObjectSrc;

          script-src =
            [
              "'self'"
              "'unsafe-inline'"
            ]
            ++ cfg.directives.additionalScriptSrc;

          style-src =
            [
              "'self'"
              "'unsafe-inline'"
            ]
            ++ cfg.directives.additionalStyleSrc;
        };
      };
    in
      pkgs.writeText "opencloud-csp-config"
      (lib.generators.toYAML {} cspConfig);

    services.opencloud.environment = {
      "PROXY_CSP_CONFIG_FILE_LOCATION" = "${cfg.configFile}";
    };
  };
}
