{
  lib,
  config,
  pkgs,
  ...
}: {
  environment.shells =
    []
    ++ lib.optionals config.programs.bash.enable [pkgs.bash]
    ++ lib.optionals config.programs.fish.enable [pkgs.fish]
    ++ lib.optionals config.programs.nushell.enable [pkgs.nushell];
}
