# Per-user default editor, a module-merge onto the users.users.<name> submodule.
# The my.{git,gh,jujutsu} wiring points their editor fields at `lib.getExe` of
# it, pinning an absolute store path instead of leaning on whatever `nvim`
# resolves to on PATH.
{lib, ...}: {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.editor = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        example = lib.literalExpression "config.my.nvf.finalPackage";
        description = ''
          Default editor package for this user. Wrappers wire their editor
          fields to `lib.getExe` of it.
        '';
      };
    });
  };
}
