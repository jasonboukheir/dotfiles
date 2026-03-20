{
  config,
  lib,
  pkgs,
  ...
}:
  lib.mkIf config.gaming.enable {
    environment.systemPackages = with pkgs; [
      cmake
      gamescope
      mangohud
      protonup-qt
      wayvr
    ];
  }
