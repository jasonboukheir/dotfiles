{ ... }:
{
    home-manager.users.jasonbk = {
  programs.git = {
    enable = true;
    userName = "Jason Elie Bou Kheir";
    userEmail = "5115126+jasonboukheir@users.noreply.github.com";
    extraConfig = {
      init.defaultBranch = "main";
    };
    ignores = [ ".DS_Store" ];
  };
    };
}
