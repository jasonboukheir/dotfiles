{pkgs, ...}: {
  programs = {
    _1password.enable = true;
    _1password-gui.enable = true;
    thunderbird.enable = false;
  };
  environment.systemPackages = with pkgs; [
    lutris
    vlc
  ];
}
