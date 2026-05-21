{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    services.clipse.enable = true;
  };
}
