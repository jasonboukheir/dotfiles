{ pkgs, ... }:
let
  onePassPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
in
{
  home-manager.users.jasonbk = {
    home.packages = [
      pkgs._1password-cli
      pkgs._1password-gui
    ];
    programs = {
      git = {
        extraConfig = {
          gpg.format = "ssh";
          "gpg \"ssh\"" = {
            program = "${pkgs._1password-gui}/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
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
  };
}
