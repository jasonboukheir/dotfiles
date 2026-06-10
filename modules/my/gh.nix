# Defaults my.gh's editor (baked as GH_EDITOR) from the per-user editor knob.
# mkDefault, so an explicit my.gh.settings.editor entry wins.
{lib, ...}: {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({config, ...}: {
      config.my.gh.settings = lib.mkIf (config.editor != null) {
        editor = lib.mkDefault (lib.getExe config.editor);
      };
    }));
  };
}
