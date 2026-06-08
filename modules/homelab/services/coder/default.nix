{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  homelabCfg = config.homelab.services.code;
  cfg = config.services.coder;
  oidcCfg = config.services.pocket-id.ensureClients.coder;
  proxyCfg = config.homelab.services.code;
  llmCfg = config.homelab.services.llm;
  idCfg = config.homelab.services.id;
  port = config.homelab.ports.values.coder;
  podmanSocket = "/run/podman/podman.sock";
  workspaceImage = "ghcr.io/coder/coder-base:latest";

  dockerDevshell = import ./templates/docker-devshell.nix {
    inherit podmanSocket workspaceImage;
    litellmBaseUrl = "https://${llmCfg.domain}/v1";
  };
in {
  config = lib.mkMerge [
    {
      homelab.services.code = {
        proxyPass = "http://${cfg.listenAddress}";
        wildcard = true;
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.coder = "auto";
      allowUnfreePackageNames = ["terraform"];

      virtualisation.podman.dockerSocket.enable = true;

      services.coder = {
        enable = true;
        package = pkgs-unstable.coder;
        listenAddress = "127.0.0.1:${toString port}";
        accessUrl = "https://${proxyCfg.domain}";
        wildcardAccessUrl = "*.${proxyCfg.domain}";
        podmanGroup = "podman";

        environment.extra = {
          CODER_OAUTH2_GITHUB_DEFAULT_PROVIDER_ENABLE = "false";
          CODER_TELEMETRY_ENABLE = "false";
        };

        oidc = {
          enable = true;
          issuerUrl = "https://${idCfg.domain}";
          clientId = oidcCfg.settings.id;
          clientSecretFile = oidcCfg.secretFile;
          signInText = "Sign in with Pocket ID";
          allowSignups = true;
          usernameField = "preferred_username";
        };

        ensureTemplates.docker-devshell = {
          modules = [dockerDevshell];
        };
      };

      services.pocket-id.ensureClients.coder = {
        dependentServices = [config.systemd.services.coder.name];
        logo = ./coder-light.svg;
        darkLogo = ./coder-dark.svg;
        settings = {
          name = "Coder";
          isPublic = false;
          # TODO: re-enable once nixpkgs ships Coder >= 2.30 (PKCE for OIDC)
          # https://github.com/coder/coder/pull/21215
          # https://github.com/NixOS/nixpkgs/pull/483203 (coder: 2.28.6 -> 2.31.10)
          pkceEnabled = false;
          launchURL = cfg.accessUrl;
          callbackURLs = [
            "${cfg.accessUrl}/api/v2/users/oidc/callback"
          ];
        };
      };
    })
  ];
}
