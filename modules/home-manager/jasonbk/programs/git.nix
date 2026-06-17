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
          # TODO: deprecate this home-manager git module in favour of the my.*
          # framework, which sources user.* from modules/jasonbk-identity.nix.
          user = {
            name = "Jason Elie Bou Kheir";
            email = "jasonbk@sunnycareboo.com";
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
