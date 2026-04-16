{pkgs, ...}: {
  imports = [
    ../../modules/home-manager/sharedModules/programs
    ../../modules/home-manager/jasonbk/programs
    ../../modules/stylix
  ];

  stylix.enable = true;

  home = {
    username = "jasonbk";
    homeDirectory = "/home/jasonbk";
    stateVersion = "25.11";
    packages = with pkgs; [
      fd
      ripgrep
      ripgrep-all
    ];
  };

  programs = {
    zmx.enable = true;
  };
}
