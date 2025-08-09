{ config, lib, ... }:
{
  config = lib.mkIf config.programs.nushell.enable {
    programs.nushell = {
      configFile.source = ./config.nu;
      extraEnv = ''
        source /etc/nushell/system-env.nu
      '';
      extraConfig = ''
        source /etc/nushell/system-config.nu
      '';
    };
    home.shell.enableNushellIntegration = true;
  };
}
