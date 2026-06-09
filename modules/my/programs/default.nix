# Auto-collects every program def (file or dir) into an attrset keyed by `name`.
# See ./CONTRACT.md.
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
