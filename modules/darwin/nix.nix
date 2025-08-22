{inputs, ...}: {
  nix.enable = true;
  nix.settings = {
    experimental-features = "nix-command flakes";
  };
  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = 5;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };
}
