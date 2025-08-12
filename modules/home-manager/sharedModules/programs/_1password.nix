{
  lib,
  config,
  pkgs,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
  onePassAgentPath =
    if isLinux
    then "\"~/.1password/agent.sock\""
    else if isDarwin
    then "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
    else null;
  onePassSshSignPath =
    if isLinux
    then "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}"
    else if isDarwin
    then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else null;
in {
  options = {
    programs._1password = {
      enable = lib.mkEnableOption "1Password";
      agentPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = onePassAgentPath;
        description = "Path to 1Password agent socket";
      };
      sshSignPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = onePassSshSignPath;
        description = "Path to 1Password ssh sign binary";
      };
    };
  };

  config = lib.mkIf config.programs._1password.enable {
    # install _1password gui and _1password cli
    home.packages = [
      pkgs._1password-gui
      pkgs._1password-cli
    ];
    programs.git = lib.mkIf (config.programs.git.enable && config.programs.ssh.enable) {
      extraConfig = {
        "gpg \"ssh\"" = {
          program = onePassSshSignPath;
        };
        user.signingKey = signingKey;
      };
    };
  };
}
