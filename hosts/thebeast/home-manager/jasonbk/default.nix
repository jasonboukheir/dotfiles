{...}: {
  home.stateVersion = "25.11";
  imports = [
    ./programs
    ./accounts.nix
  ];
}
