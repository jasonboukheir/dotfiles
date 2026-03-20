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
    environment.shellAliases = {
      rebuild-dev = "sudo nixos-rebuild boot && sudo /nix/var/nix/profiles/system/specialisation/dev/bin/switch-to-configuration switch";
    };
  };
}
