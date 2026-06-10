# Defaults my.jujutsu's user.{name,email} and ui editor fields from the per-user
# identity/editor knobs. mkDefault, so an explicit my.jujutsu.settings entry wins.
{lib, ...}: {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({config, ...}: {
      config.my.jujutsu.settings = lib.mkMerge [
        (lib.mkIf (config.identity.name != null) {
          user.name = lib.mkDefault config.identity.name;
        })
        (lib.mkIf (config.identity.email != null) {
          user.email = lib.mkDefault config.identity.email;
        })
        (lib.mkIf (config.editor != null) {
          ui.editor = lib.mkDefault (lib.getExe config.editor);
          ui.merge-editor = lib.mkDefault (lib.getExe config.editor);
        })
      ];
    }));
  };
}
