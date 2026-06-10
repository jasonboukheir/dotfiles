# Minimal hyprlang renderer mirroring home-manager's
# lib.hm.generators.toHyprconf (not available to pure defs, and nixpkgs lib
# ships no hyprlang generator): `$`-prefixed variables first, attrset values
# as `name { … }` sections, lists of attrsets as repeated sections, lists of
# scalars as duplicate keys. Shared by the hyprlang-backed my.* defs (hyprlock,
# hypridle) — defs are pure standalone files, so the renderer lives here.
{lib}: let
  render = indent: attrs: let
    isSection = v: lib.isAttrs v || (lib.isList v && v != [] && lib.all lib.isAttrs v);
    variables = lib.filterAttrs (n: _: lib.hasPrefix "$" n) attrs;
    rest = removeAttrs attrs (lib.attrNames variables);
    sections = lib.filterAttrs (_: isSection) rest;
    fields = lib.filterAttrs (n: v: !isSection v) rest;
    mkSection = name: value:
      if lib.isList value
      then lib.concatMapStringsSep "\n" (mkSection name) value
      else "${indent}${name} {\n${render "  ${indent}" value}${indent}}\n";
    mkFields = lib.generators.toKeyValue {
      listsAsDuplicateKeys = true;
      inherit indent;
    };
  in
    mkFields variables
    + lib.concatStringsSep "\n" (lib.mapAttrsToList mkSection sections)
    + mkFields fields;
in
  render ""
