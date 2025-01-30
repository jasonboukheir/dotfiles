{ ... }:
{
  homebrew.casks = [
    "ghostty"
  ];
  home-manager.users.jasonbk = {
    programs.ghostty = {
      enable = true;
      package = null;
      enableZshIntegration = true;
      settings = {
        font-size = 13;
        font-family = "FiraCode Nerd Font";
        theme = "dark:nord,light:nord-light";
        window-theme = "system";
        macos-option-as-alt = true;
      };
    };
  };
}
