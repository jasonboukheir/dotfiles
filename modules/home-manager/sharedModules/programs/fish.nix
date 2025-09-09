{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.fish.enable {
    home.shell.enableFishIntegration = lib.mkDefault true;
  };
}
