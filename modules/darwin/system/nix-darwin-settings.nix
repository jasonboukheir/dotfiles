{inputs, ...}: {
  nix.enable = true;
  nix.settings = {
    access-tokens = "!include ./.secrets/github.pat";
    experimental-features = "nix-command flakes";
  };
  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = 5;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };
}
