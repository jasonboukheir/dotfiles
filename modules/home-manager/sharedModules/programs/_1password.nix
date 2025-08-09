{
  lib,
  config,
  pkgs,
  ...
}:
let
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
  onePassAgentPath =
    if isLinux then
      "~/.1password/agent.sock"
    else if isDarwin then
      "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else
      "";
  onePassSshSignPath =
    if isLinux then
      "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}"
    else if isDarwin then
      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else
      "";
in
{
  options = {
    programs._1password = {
      enable = lib.mkEnableOption "1Password";
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
        gpg.format = "ssh";
        "gpg \"ssh\"" = {
          program = onePassSshSignPath;
        };
        commit.gpgsign = true;
        user.signingKey = signingKey;
      };
    };
    programs.ssh = lib.mkIf config.programs.ssh.enable {
      extraConfig = ''
        Host *
            IdentityAgent "${onePassAgentPath}"
      '';
      matchBlocks.brutus.forwardAgent = true;
    };
  };
}
