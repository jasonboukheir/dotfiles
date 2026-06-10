# Native (NixOS-layer) systemd user units for the omarchy desktop stack,
# replacing the home-manager service modules (issue #48). Auto-imports every
# *.nix here (except this file) so per-tool units can land independently.
{lib, ...}: let
  isUnit = name: type: type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name;
in {
  imports = lib.mapAttrsToList (name: _: ./. + "/${name}") (lib.filterAttrs isUnit (builtins.readDir ./.));
}
