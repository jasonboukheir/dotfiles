{...}: {
  imports = [
    ./home-manager
    ./options.nix
    ./audio.nix
    ./bluetooth.nix
    ./configuration.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./users.nix
    ./networking.nix
    ./nixpkgs.nix
    ./logitechBrio.nix
    ./kvmHubResume.nix
    ./printing.nix
    ./programs.nix
    ./stylix.nix
    ./secrets/radicale.nix
    ./secrets/hf-token.nix
    ./gaming
    ./omarchy.nix
    ./../../modules
    ./../../modules/nixos
    ./../../modules/omarchy
  ];
}
