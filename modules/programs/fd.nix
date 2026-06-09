{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.fd.enable =
    lib.mkEnableOption "fd system-wide" // {default = true;};

  config = lib.mkIf config.programs.fd.enable {
    environment.systemPackages = with pkgs; [fd];
  };
}
