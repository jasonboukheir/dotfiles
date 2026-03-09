{...}: {
  imports = [
    ./jasonbk
    ./sharedModules
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
  };
}
