# csp-config.nix
{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.opencloud.csp;

  # Helper to filter out empty lists to keep the generated YAML clean,
  # though OpenCloud's merge logic should handle empty lists fine.
  mkDirectives = directives:
    lib.filterAttrs (n: v: v != []) directives;
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
      # We now only construct the DELTAS.
      # The upstream application will merge these with its internal defaults (including 'self', 'unsafe-inline', etc.)
      # See https://github.com/opencloud-eu/opencloud/pull/1617
      cspConfig = {
        directives = mkDirectives {
          child-src = cfg.directives.additionalChildSrc;

          connect-src =
            [
              "https://${cfg.companionDomain}/"
              "wss://${cfg.companionDomain}/"
            ]
            ++ cfg.directives.additionalConnectSrc;

          default-src = cfg.directives.additionalDefaultSrc;

          font-src = cfg.directives.additionalFontSrc;

          frame-ancestors = cfg.directives.additionalFrameAncestors;

          frame-src =
            [
              "https://${cfg.collaboraDomain}/"
            ]
            ++ cfg.directives.additionalFrameSrc;

          img-src =
            [
              "https://${cfg.collaboraDomain}/"
            ]
            ++ cfg.directives.additionalImgSrc;

          manifest-src = cfg.directives.additionalManifestSrc;

          media-src = cfg.directives.additionalMediaSrc;

          object-src = cfg.directives.additionalObjectSrc;

          script-src = cfg.directives.additionalScriptSrc;

          style-src = cfg.directives.additionalStyleSrc;
        };
      };
    in
      pkgs.writeText "opencloud-csp-config"
      (lib.generators.toYAML {} cspConfig);

    services.opencloud.environment = {
      # This variable now triggers a MERGE with internal defaults.
      # To strictly replace defaults (old behavior), one would use PROXY_CSP_CONFIG_FILE_OVERRIDE_LOCATION
      "PROXY_CSP_CONFIG_FILE_LOCATION" = "${cfg.configFile}";
    };
  };
}
