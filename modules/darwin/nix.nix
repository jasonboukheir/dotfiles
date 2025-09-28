{inputs, ...}: {
  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = 5;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };
}
