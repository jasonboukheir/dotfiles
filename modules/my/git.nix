# Defaults my.git's user.{name,email} and editor fields from the per-user
# identity/editor knobs. mkDefault, so an explicit my.git.settings entry wins.
{lib, ...}: {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({config, ...}: {
      config.my.git.settings = lib.mkMerge [
        (lib.mkIf (config.identity.name != null) {
          user.name = lib.mkDefault config.identity.name;
        })
        (lib.mkIf (config.identity.email != null) {
          user.email = lib.mkDefault config.identity.email;
        })
        (lib.mkIf (config.editor != null) {
          core.editor = lib.mkDefault (lib.getExe config.editor);
          merge.tool = lib.mkDefault (lib.getExe config.editor);
          diff.tool = lib.mkDefault (lib.getExe config.editor);
        })
      ];
    }));
  };
}
