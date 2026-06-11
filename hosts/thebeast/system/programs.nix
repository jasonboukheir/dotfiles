{pkgs, ...}: {
  programs = {
    _1password.enable = true;
    # customAllowedBrowsers is contributed by ../helium.nix.
    _1password-gui.enable = true;
  };
  environment.systemPackages = with pkgs; [
    vlc
  ];
}
