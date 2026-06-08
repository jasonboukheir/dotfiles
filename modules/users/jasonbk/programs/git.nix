{
  lib,
  pkgs,
  ...
}: {
  users.users.jasonbk.programs.git = {
    enable = true;
    ignores = [".DS_Store"];
    settings = {
      user = {
        name = "Jason Elie Bou Kheir";
        email = "5115126+jasonboukheir@users.noreply.github.com";
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
      };
      init.defaultBranch = "main";
      core.editor = "nvim";
      merge.tool = "nvim";
      diff.tool = "nvim";
      commit.gpgsign = true;
      gpg.format = "ssh";
      "gpg \"ssh\"".program = lib.getExe' pkgs._1password-gui "op-ssh-sign";
    };
  };
}
