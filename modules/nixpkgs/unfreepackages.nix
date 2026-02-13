{
  lib,
  config,
  ...
}: let
  commonUnfreePackages = [
    "1password"
    "1password-cli"
    "claude-code"
  ];
in {
  imports = [./overlays];
  options = {
    allowUnfreePackageNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        a list of package names (as strings) that are allowed to be unfree.
        packages matching these names will bypass the `allowunfree` restriction.
      '';
    };
  };

  config = {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) (config.allowUnfreePackageNames ++ commonUnfreePackages);
  };
}
