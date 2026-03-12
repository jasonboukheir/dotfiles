{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    cmake
    gamescope
    mangohud
    protonup-qt
    wlx-overlay-s
  ];
}
