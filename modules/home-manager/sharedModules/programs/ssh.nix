{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.programs.ssh.enable {
    programs.ssh = {
      enableDefaultConfig = false;
      matchBlocks = {
        "brutus" = {
          forwardAgent = true;
        };
        "* !*.od*" = lib.mkIf (config.programs._1password.enable && config.programs._1password.agentPath != null) {
          identityAgent = config.programs._1password.agentPath;
        };
      };
    };
  };
}
