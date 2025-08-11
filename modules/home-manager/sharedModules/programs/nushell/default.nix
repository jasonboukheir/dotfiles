{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.nushell.enable {
    programs.nushell = {
      configFile.source = ./config.nu;
    };
    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
    home.shell.enableNushellIntegration = true;
  };
}
