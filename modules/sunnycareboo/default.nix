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
  };
}
