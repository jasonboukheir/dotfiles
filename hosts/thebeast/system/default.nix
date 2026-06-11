{...}: {
  imports = [
    ./options.nix
    ./audio.nix
    ./bluetooth.nix
    ./users.nix
    ./networking.nix
    ./nixpkgs.nix
    ./printing.nix
    ./programs.nix
    ./ssh.nix
    ./stylix.nix
    # Shared modules live here rather than the host default.nix so the
    # nixosTests under ../tests can pull the full system stack by
    # importing just this directory (plus ../session).
    ./../../../modules
    ./../../../modules/nixos
    ./../../../modules/omarchy
  ];
}
