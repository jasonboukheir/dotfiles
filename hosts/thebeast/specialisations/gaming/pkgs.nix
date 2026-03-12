{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    cmake
    gamescope
    mangohud
    protonup-qt
    wayvr
  ];
}
