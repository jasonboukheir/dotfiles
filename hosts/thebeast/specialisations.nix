{...}: {
  specialisation.gaming.configuration = {
    system.nixos.tags = ["gaming"];
    imports = [./specialisations/gaming];
  };
  specialisation.dev.configuration = {
    system.nixos.tags = ["dev"];
    imports = [./specialisations/dev];
  };
}
