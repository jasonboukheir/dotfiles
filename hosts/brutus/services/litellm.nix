{config, ...}: let
  port = 3200;
in {
  age.secrets."litellm/env" = {
    file = ../secrets/litellm/env.age;
  };
  virtualisation.oci-containers.containers = {
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
  services.postgresql = {
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
  sunnycareboo.services.litellm = {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
  };
}
