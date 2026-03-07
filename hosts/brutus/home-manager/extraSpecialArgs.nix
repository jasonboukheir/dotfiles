{pkgs-unstable, ...}: {
  home-manager.extraSpecialArgs = {
    inherit pkgs-unstable;
  };
}
