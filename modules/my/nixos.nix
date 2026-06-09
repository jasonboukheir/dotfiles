# NixOS entry point for my.*. System + per-user logic is shared with nix-darwin
# via ./system-scope.nix, and fish's nix-env system wiring via ./fish-system.nix.
{...}: {
  imports = [
    ./system-scope.nix
    ./fish-system.nix
  ];
}
