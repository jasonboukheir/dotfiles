{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.direnv.enable {
    programs.direnv = {
      enableBashIntegration = lib.mkIf config.programs.bash.enable true;
      enableZshIntegration = lib.mkIf config.programs.zsh.enable true;
      enableNushellIntegration = lib.mkIf config.programs.nushell.enable true;
      nix-direnv.enable = true;
    };
  };
}
