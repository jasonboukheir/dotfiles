{
  lib,
  osConfig,
  ...
}: let
  caskToProgram = {
    brave = "brave";
  };

  # Programs that use extraPackages for wrapping (unnecessary on darwin
  # since tools are already in PATH via home.packages / programs.*.enable).
  programsWithExtraPackages = [];

  caskCfg = osConfig.homebrewCasks;
in {
  config = lib.mkMerge (lib.mapAttrsToList (caskName: programName:
    lib.mkIf caskCfg.${caskName}.enable {
      programs.${programName} =
        {
          package = caskCfg.${caskName}.package;
        }
        // lib.optionalAttrs (builtins.elem programName programsWithExtraPackages) {
          extraPackages = lib.mkForce [];
        };
    })
  caskToProgram);
}
