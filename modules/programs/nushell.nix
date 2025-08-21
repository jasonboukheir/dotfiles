{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.nushell;
in {
  options.programs.nushell.enable = mkOption {
    type = types.bool;
    default = true;
    description = "Whether to configure Nushell as an interactive shell.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nushell
    ];
  };
}
