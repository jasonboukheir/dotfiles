{...}: {
  imports = [
    ./home-manager
    ./specialisations/gaming/options.nix
    ./audio.nix
    ./bluetooth.nix
    ./configuration.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./users.nix
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
