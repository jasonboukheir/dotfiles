{ inputs, pkgs, ... }:
{
  imports = [
    ./home-manager.nix
    ./fonts.nix
    ./users.nix
  ];

  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = 4;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };
}
