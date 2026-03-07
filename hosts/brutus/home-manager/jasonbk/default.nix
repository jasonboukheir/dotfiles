{pkgs-unstable, ...}: {
  home.stateVersion = "25.05";
  programs = {
    claude-code.enable = true;
    claude-code.package = pkgs-unstable.claude-code;
    gemini-cli.enable = true;
    gemini-cli.package = pkgs-unstable.gemini-cli;
  };
}
