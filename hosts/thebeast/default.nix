{...}: {
  imports = [
    ./home-manager
    ./audio.nix
    ./bluetooth.nix
    ./configuration.nix
    ./desktop.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./jovian.nix
    ./networking.nix
    ./nixpkgs.nix
    ./printing.nix
    ./programs.nix
    ./stylix.nix
    ./secrets/radicale.nix
    ./../../modules
    ./../../modules/nixos
    ./../../modules/omarchy
  ];
}
