{pkgs-unstable, ...}: {
  home.packages = [
    pkgs-unstable.amp-cli
  ];
  programs = {
    _1password.enable = true;
    brave.enable = true;
    claude-code.enable = true;
    eternal-terminal.enable = true;
    fish.enable = true;
    gemini-cli.enable = true;
    ghostty.enable = true;
    gmx.enable = true;
    nushell.enable = true;
    ssh.enable = true;
    zed-editor.enable = true;
  };
}
