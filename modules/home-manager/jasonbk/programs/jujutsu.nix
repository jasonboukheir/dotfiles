{
  config,
  lib,
  ...
}: let
  cfg = config.programs.jujutsu;
  sshCfg = config.programs.ssh;
in {
  config.programs.jujutsu = lib.mkMerge [
    {enable = lib.mkDefault true;}
    (lib.mkIf cfg.enable {
      settings = lib.mkMerge [
        {
          # TODO: deprecate this home-manager jujutsu module in favour of the my.*
          # framework, which sources user.* from modules/jasonbk-identity.nix.
          user = {
            name = "Jason Elie Bou Kheir";
            email = "jasonbk@sunnycareboo.com";
          };
          ui = {
            editor = "nvim";
            merge-editor = "nvim";
            pager = "less -FRX";
            default-command = "log";
          };
          git = {
            colocate = true;
            private-commits = "description(glob:'wip:*')";
          };
        }
        (lib.mkIf sshCfg.enable {
          signing = {
            behavior = "own";
            backend = "ssh";
          };
        })
      ];
    })
  ];
}
