{ ... }:
{
  home-manager.users.jasonbk = {
    programs.neovim = {
      enable = true;
      vimAlias = true;
    };
  };
}
