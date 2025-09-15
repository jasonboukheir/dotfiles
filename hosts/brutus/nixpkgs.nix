{
  lib,
  config,
  ...
}: {
  options = {
    allowUnfreePackageNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        A list of package names (as strings) that are allowed to be unfree.
        Packages matching these names will bypass the `allowUnfree` restriction.
      '';
    };
  };

  config = {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) config.allowUnfreePackageNames;
  };
}
