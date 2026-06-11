# Standalone-HM host: no system layer to carry NixOS's programs._1password*,
# so the nixGL-wrapped GUI + op CLI install straight from home.packages, with
# the autostart entry and ssh-signing wiring (which the deleted shared
# _1password home-manager module used to inject) inlined here (issue #46).
{
  config,
  lib,
  pkgs,
  ...
}: let
  onePassword = config.lib.nixGL.wrap pkgs._1password-gui;
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGEXFObvyFbGAgq3Lob/+2SPBXfFBmguTmJDLcJlysJ";
in {
  home.packages = [
    onePassword
    pkgs._1password-cli
  ];

  # The 1Password agent wins SSH_AUTH_SOCK on this host.
  home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";

  xdg.configFile."autostart/1password.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=1Password
    Exec=${lib.getExe onePassword} --silent
    Icon=1password
    StartupWMClass=1Password
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';

  programs.git.settings = {
    user.signingKey = signingKey;
    gpg.format = "ssh";
    commit.gpgsign = true;
    # op-ssh-sign does no GL; the unwrapped package's binary is fine.
    "gpg \"ssh\"".program = lib.getExe' pkgs._1password-gui "op-ssh-sign";
  };

  programs.jujutsu.settings.signing = {
    behavior = "own";
    backend = "ssh";
    key = signingKey;
  };
}
