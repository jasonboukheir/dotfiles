{
  lib,
  config,
  ...
}: {
  imports = [./overlays];
  options = {
    allowunfreepackagenames = lib.mkoption {
      type = lib.types.listof lib.types.str;
      default = [];
      description = ''
        a list of package names (as strings) that are allowed to be unfree.
        packages matching these names will bypass the `allowunfree` restriction.
      '';
    };
  };

  config = {
    nixpkgs.config.allowunfreepredicate = pkg:
      builtins.elem (lib.getname pkg) config.allowunfreepackagenames;
  };
}
