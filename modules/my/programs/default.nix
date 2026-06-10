# Auto-collects every program def (file or dir) into an attrset keyed by `name`.
# Each def is a pure `{lib, pkgs}: {name; build; …}` function — it never receives
# the ambient module `config`, which is what keeps `build` pure (see `buildTool`
# in ../lib.nix for the full set of inputs a build may read).
{
  lib,
  pkgs,
}: let
  isDef = name: type:
    type
    == "directory"
    || (type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name);
  files = lib.filterAttrs isDef (builtins.readDir ./.);
  defs = lib.mapAttrsToList (fname: _: import (./. + "/${fname}") {inherit lib pkgs;}) files;
in
  lib.listToAttrs (map (def: lib.nameValuePair def.name def) defs)
