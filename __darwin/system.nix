{ rev, ... }:
{
  imports = [ ./system/defaults.nix ];

  system = {
    stateVersion = 4;
    configurationRevision = rev;
  };
}
