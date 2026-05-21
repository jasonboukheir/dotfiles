{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    services.wl-clip-persist.enable = true;
  };
}
