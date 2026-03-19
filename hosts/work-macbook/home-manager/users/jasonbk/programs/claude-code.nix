{lib, ...}: {
  programs.claude-code = {
    enable = true;
    package = null;
    settings = lib.mkForce {};
  };
}
