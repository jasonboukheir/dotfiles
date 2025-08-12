{
  config,
  lib,
  pkgs,
  ...
}: let
  onePassAgentPath =
    if pkgs.stdenv.isLinux
    then "\"~/.1password/agent.sock\""
    else if pkgs.stdenv.isDarwin
    then "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
    else "";
in {
  config = lib.mkIf config.programs.ssh.enable {
    programs.ssh = {
      matchBlocks = {
        "brutus" = {
          forwardAgent = true;
        };
        "* !*.od*" = lib.mkIf config.programs._1password.enable {
          identityAgent = onePassAgentPath;
        };
      };
    };
  };
}
