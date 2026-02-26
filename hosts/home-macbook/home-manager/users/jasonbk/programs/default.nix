{pkgs-unstable, ...}: {
  programs = {
    _1password.enable = true;
    brave.enable = true;
    claude-code.enable = true;
    claude-code.package = pkgs-unstable.claude-code;
    fish.enable = true;
    gemini-cli.enable = true;
    gemini-cli.package = pkgs-unstable.gemini-cli;
    ghostty.enable = true;
    nushell.enable = true;
    ssh.enable = true;
    zed-editor.enable = true;
  };
}
