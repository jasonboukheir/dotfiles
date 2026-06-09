# Auto-collects every program definition (*.nix here, except this file) into an
# attrset keyed by each def's `name`. Drop a new modules/my/programs/<tool>.nix
# conforming to ./CONTRACT.md and it's picked up automatically — no edits here.
{
  lib,
  pkgs,
}: let
  # A def is either a `<tool>.nix` file or a `<tool>/` directory (with its own
  # default.nix returning the def). CONTRACT.md and this default.nix are skipped.
  isDef = name: type:
    type
    == "directory"
    || (type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name);
  files = lib.filterAttrs isDef (builtins.readDir ./.);
  defs = lib.mapAttrsToList (fname: _: import (./. + "/${fname}") {inherit lib pkgs;}) files;
in
  lib.listToAttrs (map (def: lib.nameValuePair def.name def) defs)
