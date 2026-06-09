{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.ripgrep.enable =
    lib.mkEnableOption "ripgrep (+ ripgrep-all) system-wide" // {default = true;};

  config = lib.mkIf config.programs.ripgrep.enable {
    environment.systemPackages = with pkgs; [ripgrep ripgrep-all];
  };
}
