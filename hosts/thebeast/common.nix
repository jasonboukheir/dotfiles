{...}: {
  imports = [
    ./software.nix
    ./home-manager
    ./configuration.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./secrets/radicale.nix
    ./secrets/hf-token.nix
    ./secrets/users.nix
  ];
}
