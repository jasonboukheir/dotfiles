{pkgs-unstable, ...}: {
  home.packages = [
    pkgs-unstable.amp-cli
  ];
  programs = {
    _1password.enable = true;
    _1password.sshAuthSock.enable = true;
    brave.enable = true;
    claude-code.enable = true;
    fish.enable = true;
    ghostty.enable = true;
    nushell.enable = true;
    ssh.enable = true;
  };
}
