{...}: {
  home-manager.sharedModules = [
    ./sharedModules
    ../../../modules/home-manager/sharedModules/programs/nvf/meta.nix
  ];
  imports = [
    ./users
  ];
}
