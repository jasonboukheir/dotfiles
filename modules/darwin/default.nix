{ pkgs, lib, ... }:
{
  imports = lib.mkIf pkgs.stdenv.isDarwin [
    ./programs
    ./system
  ];
}
