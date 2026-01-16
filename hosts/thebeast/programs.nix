{pkgs, ...}: {
  programs = {
    _1password.enable = true;
    _1password-gui.enable = true;
  };
  environment.systemPackages = with pkgs; [
    lutris
  ];
}
