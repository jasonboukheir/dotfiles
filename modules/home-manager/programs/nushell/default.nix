{ config, lib, ... }:
{
  config = lib.mkIf config.programs.nushell.enable {
    programs.nushell = {
      configFile.source = ./config.nu;
    };
    home.shell.enableNushellIntegration = true;
  };
}
