{thebeastModules, ...}: {
  specialisation.dev = {
    inheritParentConfig = false;
    configuration = {
      system.nixos.tags = ["dev"];
      imports =
        thebeastModules
        ++ [
          ./common.nix
          ./specialisations/dev
        ];
    };
  };
}
