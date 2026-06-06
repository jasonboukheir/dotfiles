{...}: {
  home.stateVersion = "25.05";
  programs = {
    claude-code.enable = true;
    antigravity-cli.enable = true;
    zmx.enable = true;
  };
  services.ssh-agent-switcher.enable = true;
}
