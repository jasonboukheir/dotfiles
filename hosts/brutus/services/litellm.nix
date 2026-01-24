{
  lib,
  config,
  ...
}: let
  port = 3200;
  cfg = config.services.litellm-container;
in {
  options = {
    services.litellm-container.enable = lib.mkEnableOption "litellm-container";
  };

  config = {
    services.litellm-container.enable = true;
    age.secrets."litellm/env" = lib.mkIf cfg.enable {
      file = ../secrets/litellm/env.age;
    };
    virtualisation.oci-containers.containers = lib.mkIf cfg.enable {
      litellm = {
        autoStart = true;
        image = "berriai/litellm:main-stable";
        cmd = [
          "--port=${toString port}"
          "--host=localhost"
        ];
        environment = {
          "DATABASE_URL" = "postgresql://litellm@localhost:5432/litellm";
          "STORE_MODEL_IN_DB" = "True";
        };
        environmentFiles = [
          config.age.secrets."litellm/env".path
        ];
        extraOptions = [
          "--network=host"
        ];
      };
    };
    services.postgresql = lib.mkIf cfg.enable {
      ensureUsers = [
        {
          name = "litellm";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = [
        "litellm"
      ];
    };
    sunnycareboo.services.litellm = lib.mkIf cfg.enable {
      enable = true;
      proxyPass = "http://localhost:${toString port}";
    };
  };
}
