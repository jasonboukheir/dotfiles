{lib, ...}: {
  options.services.radicale = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 5232;
      description = "Port that radicale is being served on";
    };
  };
}
