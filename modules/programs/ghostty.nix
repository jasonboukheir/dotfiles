{ inputs, system, ... }:
{
  home-manager.users.jasonbk = {
    imports = [
      inputs.ghostty-hm.homeModules.default
    ];
    programs.ghostty = {
      enable = true;
      # flake not supported in darwin... yet
      package = null;
      shellIntegration.enable = true;
      settings = {
        font-size = 12;
        font-family = "FiraCode Nerd Font";
        theme = "dark:nord,light:nord-light";
        window-theme = "system";
        macos-option-as-alt = true;
      };
    };
  };
}
