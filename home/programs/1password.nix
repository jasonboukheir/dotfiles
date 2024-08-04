{ config, pkgs, ... }:
let
  onePassSshProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  onePassPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
in
{
  programs = {
    git = {
      extraConfig = {
        gpg.format = "ssh";
        "gpg \"ssh\"" = {
          program = onePassSshProgram;
        };
        commit.gpgsign = true;
        user.signingKey = signingKey;
      };
    };
    ssh = {
      enable = true;
      extraConfig = ''
        Host *
            IdentityAgent "${onePassPath}"
      '';
    };
  };
}