{lib, ...}:
with lib; {
  imports = [
    ./services.nix
    ./wellKnown.nix
  ];

  options.sunnycareboo = {
    enable = mkEnableOption "Sunnycareboo service management";

    baseDomain = mkOption {
      type = types.str;
      default = "sunnycareboo.com";
      description = "Base domain for all services";
    };

    mtls.caCertFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to the CA certificate file for mTLS client verification.
        When set, external services will have mTLS enabled by default.
      '';
    };

    smtp = {
      host = mkOption {
        type = types.str;
        description = "SMTP server hostname";
      };

      port = mkOption {
        type = types.port;
        default = 587;
        description = "SMTP server port";
      };

      from = mkOption {
        type = types.str;
        description = "From address for outgoing email";
      };

      username = mkOption {
        type = types.str;
        description = "SMTP authentication username";
      };

      passwordFile = mkOption {
        type = types.path;
        description = "Path to file containing the SMTP password";
      };
    };
  };
}
