{lib, ...}: {
  options = {
    services.brutus.enable = lib.mkEnableOption "All Brutus services";
  };

  config = {
    services.brutus.enable = lib.mkDefault true;
  };
}
