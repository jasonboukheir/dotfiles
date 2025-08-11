{
  pkgs,
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.programs.zsh.enable {
    programs.zsh = {
      oh-my-zsh = {
        enable = true;
        plugins = ["git"];
      };
      shellAliases = {
        git = "${pkgs.git}/bin/git";
      };
    };
  };
}
