# NixOS entry point for my.*. System + per-user logic is shared with nix-darwin
# via ./system-scope.nix.
{...}: {
  imports = [./system-scope.nix];
}
