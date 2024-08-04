{ pkgs, inputs, ... }:
{
  imports = [
    ./system/defaults.nix
  ];

  system = {
    stateVersion = 4;
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
  };
}