{...}: {
  imports = [
    ./greetd.nix
    ./switch.nix
  ];

  specialisation.dev.configuration = {
    system.nixos.tags = ["dev"];
    imports = [./dev];
    gaming.enable = false;
  };
}
