{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.programs.fish.enable {
    home.shell.enableFishIntegration = lib.mkDefault true;
    programs = {
      fish = {
        #        shellInit = ''
        #          fish_config theme choose Nord
        #        '';
        plugins = [
          {
            name = "plugin-git";
            src = pkgs.fishPlugins.plugin-git.src;
          }
        ];
      };
    };
  };
}
