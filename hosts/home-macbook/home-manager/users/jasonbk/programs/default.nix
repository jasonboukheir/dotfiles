{pkgs-unstable, ...}: {
  home.packages = [
    pkgs-unstable.amp-cli
  ];
  programs = {
    _1password.enable = true;
    _1password.sshAuthSock.enable = true;
    fish.enable = true;
    ssh.enable = true;
  };
}
