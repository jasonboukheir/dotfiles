{ ... }:
{
  home-manager.users.jasonbk = {
    programs.zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" ];
      };
      initExtra = ''
        eval "$(starship init zsh)"
      '';
    };
  };
}
