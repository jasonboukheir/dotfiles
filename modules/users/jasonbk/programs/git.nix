{
  lib,
  pkgs,
  ...
}: {
  users.users.jasonbk.programs.git = {
    enable = true;
    ignores = [".DS_Store"];
    settings = {
      # TODO: replace name/email with users.users.jasonbk.identity
      # https://github.com/jasonboukheir/dotfiles/issues/63
      user.name = "Jason Elie Bou Kheir";
      user.email = "5115126+jasonboukheir@users.noreply.github.com";
      init.defaultBranch = "main";
      # TODO: replace the "nvim" literals with users.users.jasonbk.editor
      # https://github.com/jasonboukheir/dotfiles/issues/62
      core.editor = "nvim";
      merge.tool = "nvim";
      diff.tool = "nvim";
      # TODO: ssh signing flattened from HM ssh/1Password; fold back into the
      # ssh/1Password module once it lands (op-ssh-sign path is linux-only).
      # https://github.com/jasonboukheir/dotfiles/issues/46
      user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
      commit.gpgsign = true;
      gpg.format = "ssh";
      "gpg \"ssh\"".program = lib.getExe' pkgs._1password-gui "op-ssh-sign";
    };
  };
}
