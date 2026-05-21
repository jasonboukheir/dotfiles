{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    services.hyprsunset.enable = true;
  };
}
