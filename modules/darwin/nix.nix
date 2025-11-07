{inputs, ...}: {
  nix.enable = false;
  #  nix.linux-builder = {
  #    enable = true;
  #    systems = ["x86_64-linux" "aarch64-linux"];
  #    config.boot.binfmt.emulatedSystems = ["x86_64-linux"];
  #  };
  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = 5;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };
}
