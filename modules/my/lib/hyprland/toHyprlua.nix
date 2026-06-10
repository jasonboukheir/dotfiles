# Lua-config renderer mirroring home-manager's hyprland `configType = "lua"`
# output (modules/services/window-managers/hyprland.nix at the pinned HM rev),
# so the my.hyprland def renders the same hyprland.lua the HM module did:
# `_var` attrs become `local` bindings (rendered first), every other attr
# becomes one `hl.<name>(…)` call per value, `_args` lists become
# multi-argument calls, and `lib.generators.mkLuaInline` values pass through
# as raw Lua. Section order follows hyprlang's important prefixes, then
# alphabetical — same as HM, so on-host diffs against the old file stay clean.
{lib}: let
  toLua = lib.generators.toLua {};

  importantPrefixes = ["$" "bezier" "curve" "name" "output"];

  renderArgs = value:
    if lib.isAttrs value && value ? _args
    then lib.concatMapStringsSep ", " toLua value._args
    else toLua value;

  renderSection = name: text:
    lib.optionalString (text != "") ''
      -- ${name}
      ${text}
    '';
in
  settings: let
    names = lib.sort lib.lessThan (lib.attrNames settings);
    luaLocalNames =
      builtins.filter (
        name: lib.isAttrs settings.${name} && settings.${name} ? _var
      )
      names;
    settingNames = builtins.filter (name: !(builtins.elem name luaLocalNames)) names;
    importantNames = lib.unique (
      lib.concatMap (
        prefix: builtins.filter (name: lib.hasPrefix prefix name) settingNames
      )
      importantPrefixes
    );
    orderedNames =
      importantNames ++ builtins.filter (name: !(builtins.elem name importantNames)) settingNames;
    renderLocal = name: let
      value = settings.${name};
    in "local ${value.name or name} = ${renderArgs value._var}\n";
    renderCall = name: value: "hl.${name}(${renderArgs value})\n";
    renderCalls = name: value:
      lib.concatMapStrings (renderCall name) (
        if builtins.isList value
        then value
        else [value]
      );
  in
    lib.optionalString (luaLocalNames != []) (
      renderSection "settings.locals" (lib.concatMapStrings renderLocal luaLocalNames)
    )
    + lib.concatMapStrings (
      name: renderSection "settings.${name}" (renderCalls name settings.${name})
    )
    orderedNames
