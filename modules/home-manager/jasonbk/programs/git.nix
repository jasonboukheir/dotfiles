{
  config,
  lib,
  ...
}: {
  programs.git = {
    enable = lib.mkDefault true;
    lfs.enable = true;
    userName = "Jason Elie Bou Kheir";
    userEmail = "5115126+jasonboukheir@users.noreply.github.com";
    extraConfig = lib.mkMerge [
      {
        init.defaultBranch = "main";
        merge.tool = "nvim";
        diff.tool = "nvim";
        core.editor = "nvim";
      }
      (lib.mkIf config.programs.ssh.enable {
        gpg.format = "ssh";
        commit.gpgsign = true;
      })
    ];
    ignores = [".DS_Store"];
  };
}
