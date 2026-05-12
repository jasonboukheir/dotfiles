{
  config,
  lib,
  ...
}: {
  programs._1password.enable = true;
  programs._1password.sshAuthSock.enable = true;

  xdg.configFile."autostart/1password.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=1Password
    Exec=${lib.getExe config.programs._1password.package} --silent
    Icon=1password
    StartupWMClass=1Password
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
