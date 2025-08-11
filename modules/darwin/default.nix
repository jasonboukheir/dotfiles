{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./programs
    ./system
  ];
}
