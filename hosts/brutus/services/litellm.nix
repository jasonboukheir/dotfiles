{
  pkgs,
  lib,
  ...
}: {
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
  # services.litellm = {
  #   enable = true;
  #   port = 3200;
  #   environment = {
  #     "DATABASE_URL" = "postgresql://litellm@localhost:5432/litellm";
  #   };
  #   environmentFile = "/var/lib/secrets/liteLlmSecrets";
  # };
  # systemd.services.litellm = {
  #   serviceConfig = {
  #     ExecStartPre = "${lib.getExe pkgs.prisma} generate --schema ${pkgs.litellm}/lib/python3.13/site-packages/litellm/proxy/schema.prisma";
  #   };
  # };
}
