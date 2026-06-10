{...}: {
  home.stateVersion = "25.05";
  programs = {
    zmx.enable = true;
  };
  services.ssh-agent-switcher.enable = true;
}
