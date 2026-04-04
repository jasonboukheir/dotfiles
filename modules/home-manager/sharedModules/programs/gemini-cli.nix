{pkgs-unstable, ...}: {
  programs.gemini-cli = {
    package = pkgs-unstable.gemini-cli;
  };
}
