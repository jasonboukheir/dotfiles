{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.git ];
  home-manager.users.jasonbk = {
    programs.git = {
      enable = true;
      lfs.enable = true;
      userName = "Jason Elie Bou Kheir";
      userEmail = "5115126+jasonboukheir@users.noreply.github.com";
      extraConfig = {
        init.defaultBranch = "main";
        merge.tool = "nvim";
        diff.tool = "nvim";
        core.editor = "nvim";
      };
      ignores = [ ".DS_Store" ];
    };
  };
}
