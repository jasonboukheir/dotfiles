{
  config,
  lib,
  ...
}: {
  programs.git = {
    enable = lib.mkDefault true;
    lfs.enable = true;
    settings = lib.mkMerge [
      {
        user = {
          name = "Jason Elie Bou Kheir";
          email = "5115126+jasonboukheir@users.noreply.github.com";
        };
      }
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
