{pkgs-unstable, ...}: {
  environment.systemPackages = with pkgs-unstable; [
    claude-code
    gemini-cli
  ];
}
