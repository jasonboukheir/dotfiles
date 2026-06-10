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
    # A mkWrapped package carries its wrapped name ("<tool>-wrapped") but keeps
    # the unwrapped derivation under passthru.unwrapped, so an unfree tool stays
    # allowed once wrapped (e.g. my.claude-code's claude wrapper). At check-meta
    # time the predicate sees the raw mkDerivation args, where `unwrapped` is
    # still nested under `passthru`, so look there too.
    nixpkgs.config.allowUnfreePredicate = pkg: let
      allowed = config.allowUnfreePackageNames ++ commonUnfreePackages;
      unwrapped = pkg.unwrapped or pkg.passthru.unwrapped or null;
      names = [(lib.getName pkg)] ++ lib.optional (unwrapped != null) (lib.getName unwrapped);
    in
      lib.any (name: builtins.elem name allowed) names;
  };
}
