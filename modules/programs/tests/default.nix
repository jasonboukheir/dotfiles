{
  pkgs,
  inputs ? null,
}: let
  inherit (pkgs) lib;
  isTest = name: type: type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name;
  tests = lib.filterAttrs isTest (builtins.readDir ./.);
in
  lib.mapAttrs' (
    name: _:
      lib.nameValuePair (lib.removeSuffix ".nix" name)
      (import (./. + "/${name}") {inherit pkgs inputs;})
  )
  tests
