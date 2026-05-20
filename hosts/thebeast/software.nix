{...}: {
  imports = [
    ./options.nix
    ./audio.nix
    ./bluetooth.nix
    ./users.nix
    ./networking.nix
    ./nixpkgs.nix
    ./logitechBrio.nix
    ./kvmHubResume.nix
    ./printing.nix
    ./programs.nix
    ./stylix.nix
    ./../../modules
    ./../../modules/nixos
    ./../../modules/omarchy
  ];
}
