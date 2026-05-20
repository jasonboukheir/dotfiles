{lib, ...}: {
  imports = [
    ./greetd.nix
    ./switch.nix
  ];

  specialisation.dev.configuration = {
    system.nixos.tags = ["dev"];
    imports = [./dev];
    # mkForce so that a future `gaming.enable = lib.mkForce true` anywhere
    # in the parent toplevel (e.g. a jovian preset that hardens the flag)
    # can't silently boot the dev spec with gaming on.
    gaming.enable = lib.mkForce false;
  };
}
