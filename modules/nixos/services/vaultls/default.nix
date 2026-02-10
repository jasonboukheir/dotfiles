{
  config,
  lib,
  ...
}: let
  cfg = config.services.vaultls-container;
in {
  options.services.vaultls-container = {
    enable = lib.mkEnableOption "VaulTLS container";

    url = lib.mkOption {
      type = lib.types.str;
      description = "Public URL where VaulTLS will be accessible";
      example = "https://vaultls.example.com/";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5173;
      description = "Port the container will be bound to";
    };

    databaseSecretPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "path to secret that will be used to encrypt the database. If not provided, one will be generated";
    };
  };

  config =
    lib.mkIf cfg.enable {
    };
}
