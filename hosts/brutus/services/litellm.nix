{...}: {
  services.litellm = {
    enable = true;
    port = 3200;
    environment = {
      "DATABASE_USER" = "litellm";
      "DATABASE_PORT" = "5432";
      "DATABASE_HOST" = "127.0.0.1";
      "DATABASE_NAME" = "litellm";
    };
    environmentFile = "/var/lib/secrets/liteLlmSecrets";
  };
}
