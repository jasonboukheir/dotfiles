{
  lib,
  config,
  pkgs,
  ...
}: {
  environment.shells =
    []
    ++ lib.optionals config.programs.bash.enable [pkgs.bash]
    ++ lib.optionals config.programs.fish.enable [config.programs.fish.package]
    ++ lib.optionals config.programs.nushell.enable [pkgs.nushell];
}
