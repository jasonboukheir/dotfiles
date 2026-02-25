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
  };
}
