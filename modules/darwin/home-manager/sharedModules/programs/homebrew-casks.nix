{
  lib,
  osConfig,
  ...
}: let
  caskToProgram = {
    brave = "brave";
    zed = "zed-editor";
  };

  caskCfg = osConfig.homebrewCasks;
in {
  config = lib.mkMerge (lib.mapAttrsToList (caskName: programName:
    lib.mkIf caskCfg.${caskName}.enable {
      programs.${programName}.package = caskCfg.${caskName}.package;
    })
  caskToProgram);
}
