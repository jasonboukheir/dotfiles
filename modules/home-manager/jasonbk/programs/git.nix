{ config, lib, ... }:
{
  config.programs.git = lib.mkDefault true;
  config = lib.mkIf config.programs.git.enable {
    lfs.enable = true;
    userName = "Jason Elie Bou Kheir";
    userEmail = "5115126+jasonboukheir@users.noreply.github.com";
    extraConfig = {
      init.defaultBranch = "main";
      merge.tool = "nvim";
      diff.tool = "nvim";
      core.editor = "nvim";
    };
    extraConfig = lib.mkIf config.programs.ssh.enable {
      gpg.format = "ssh";
      commit.gpgsign = true;
      user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
    };
  }
}
