{...}: {
  virtualisation.oci-containers.containers = {
    litellm = {
      autoStart = true;
      image = "berriai/litellm:main-stable";
      cmd = [
        "--port=3200"
        "--host=localhost"
      ];
      environment = {
        "DATABASE_URL" = "postgresql://litellm@localhost:5432/litellm";
      };
      environmentFiles = [
        "/var/lib/secrets/liteLlmSecrets"
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
}
