{ ... }:
{
  homebrew.casks = [ "zed" ];
  home-manager.users.jasonbk = {
    home.file = {
      ".config/zed" = {
        source = ./zed;
        recursive = true;
      };
    };
  };
}
