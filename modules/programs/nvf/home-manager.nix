# nvf (neovim) as a standalone-built package in a user's home.packages, for the
# standalone home-manager hosts (work-devserver, jasonbk-fedora) which have no
# system layer. Imported explicitly by those hosts; hosts with a system layer
# use ./default.nix (environment.systemPackages) instead. Part of #43.
{
  config,
  lib,
  ...
}: {
  imports = [
    ./options.nix
    ./config.nix
  ];

  config = lib.mkIf config.programs.nvf.enable {
    home.packages = [config.programs.nvf.finalPackage];
  };
}
