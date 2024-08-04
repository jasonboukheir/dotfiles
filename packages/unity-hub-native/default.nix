# default.nix
let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable";
  pkgs = import nixpkgs { config = {}; overlays = []; };
in
{
  unity-hub-native = pkgs.callPackage ./unity-hub-native.nix { };
}
