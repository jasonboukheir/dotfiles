{
  lib,
  config,
  ...
}: let
  cfg = config.services.litellm;
  port = 3200;
in {
  services.litellm = {
    enable = true;
    port = port;
    environment = {
      DATABASE_URL = "postgresql://litellm@localhost:5432/litellm";
      STORE_MODEL_IN_DB = "True";
    };
    environmentFile = config.age.secrets."litellm/env".path;
  };

  age.secrets."litellm/env" = lib.mkIf cfg.enable {
    file = ../secrets/litellm/env.age;
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

  sunnycareboo.services.llm = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://${cfg.host}:${toString cfg.port}";
  };
}
