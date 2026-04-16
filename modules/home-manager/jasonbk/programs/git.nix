{
  config,
  lib,
  ...
}: let
  cfg = config.programs.git;
  sshCfg = config.programs.ssh;
in {
  config.programs.git = lib.mkMerge [
    {enable = lib.mkDefault true;}
    (lib.mkIf cfg.enable {
      lfs.enable = true;
      settings = lib.mkMerge [
        {
          user = {
            name = "Jason Elie Bou Kheir";
            email = "5115126+jasonboukheir@users.noreply.github.com";
          };
          init.defaultBranch = "main";
          merge.tool = "nvim";
          diff.tool = "nvim";
          core.editor = "nvim";
        }
        (lib.mkIf sshCfg.enable {
          gpg.format = "ssh";
          commit.gpgsign = true;
        })
      ];
      ignores = [".DS_Store"];
    })
  ];
}
