{
  lib,
  config,
  pkgs,
  ...
}:
{
  options = {
    programs.devbox = {
      enable = lib.mkEnableOption "Enable Devbox";
    };
  };

  config = lib.mkIf config.programs.devbox.enable {
    programs.direnv.enable = config.programs.zed-editor.enable or false;
    home.packages = with pkgs; [
      devbox
    ];
  };
}
