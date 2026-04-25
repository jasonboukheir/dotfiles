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
      sshAuthSock.enable = lib.mkEnableOption "setting SSH_AUTH_SOCK to the 1Password agent socket";
    };
  };

  config = lib.mkIf config.programs._1password.enable {
    home.packages = [
      pkgs._1password-gui
      pkgs._1password-cli
    ];
    home.sessionVariables = let
      homeDir = config.home.homeDirectory;
      agentSocket =
        if isLinux
        then "${homeDir}/.1password/agent.sock"
        else if isDarwin
        then "${homeDir}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        else null;
    in
      lib.mkIf (config.programs._1password.sshAuthSock.enable && agentSocket != null) {
        SSH_AUTH_SOCK = agentSocket;
      };
    programs.git = lib.mkIf (config.programs.git.enable && config.programs.ssh.enable) {
      settings = {
        "gpg \"ssh\"" = {
          program = onePassSshSignPath;
        };
        user.signingKey = signingKey;
      };
    };
    programs.jujutsu = lib.mkIf (config.programs.jujutsu.enable && config.programs.ssh.enable) {
      settings.signing.key = signingKey;
    };
  };
}
