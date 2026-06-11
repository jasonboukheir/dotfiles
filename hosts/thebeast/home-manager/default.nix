{...}: {
  imports = [
    ./sharedModules
  ];
  home-manager.users.jasonbk.imports = [./jasonbk];
  home-manager.users.gamer.imports = [./gamer];
}
