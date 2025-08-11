{
  config,
  options,
  lib,
  pkgs,
  ...
}: {
  options = {
    programs.git = {
      enable = lib.mkEnableOption "git";
      lfs.enable = lib.mkEnableOption "git-lfs";
    };
  };
  config = lib.mkIf config.programs.git.enable {
    environment.systemPackages = with pkgs;
      [
        git
      ]
      ++ lib.optionals config.programs.git.lfs.enable [git-lfs];
  };
}
