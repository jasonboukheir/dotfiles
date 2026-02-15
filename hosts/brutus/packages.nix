{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    claude-code
    gemini-cli
  ];
}
