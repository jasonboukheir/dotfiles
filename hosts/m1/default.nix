{ pkgs, ... }:
{
  imports = [
    ./../../modules
    ./../../modules/darwin
    ./programs
    ./system
  ];
}