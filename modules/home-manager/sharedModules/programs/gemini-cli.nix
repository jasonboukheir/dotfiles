{pkgs-unstable, ...}: {
  programs.antigravity-cli = {
    package = pkgs-unstable.gemini-cli;
  };
}
