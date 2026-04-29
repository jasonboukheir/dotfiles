{
  config,
  lib,
  ...
}: let
  cfg = config.services.coder;
  oidcCfg = config.services.pocket-id.ensureClients.coder;
  proxyCfg = config.sunnycareboo.services.code;
  llmCfg = config.sunnycareboo.services.llm;
  idCfg = config.sunnycareboo.services.id;
  port = config.sunnycareboo.ports.values.coder;
  podmanSocket = "/run/podman/podman.sock";
  workspaceImage = "ghcr.io/coder/coder-base:latest";

  dockerDevshell = import ./templates/docker-devshell.nix {
    inherit podmanSocket workspaceImage;
    litellmBaseUrl = "https://${llmCfg.domain}/v1";
  };
in {
  sunnycareboo.ports.allocate.coder = lib.mkIf cfg.enable "auto";
  allowUnfreePackageNames = lib.optionals cfg.enable ["terraform"];

  virtualisation.podman.dockerSocket.enable = lib.mkIf cfg.enable true;

  services.coder = {
    enable = true;
    listenAddress = "127.0.0.1:${toString port}";
    accessUrl = "https://${proxyCfg.domain}";
    wildcardAccessUrl = "*.${proxyCfg.domain}";
    podmanGroup = "podman";

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

  services.pocket-id.ensureClients.coder = lib.mkIf cfg.enable {
    dependentServices = [config.systemd.services.coder.name];
    settings = {
      name = "Coder";
      isPublic = false;
      launchURL = cfg.accessUrl;
      callbackURLs = [
        "${cfg.accessUrl}/api/v2/users/oidc/callback"
      ];
    };
  };

  sunnycareboo.services.code = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://${cfg.listenAddress}";
    wildcard = true;
  };
}
