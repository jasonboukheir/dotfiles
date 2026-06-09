# nix-darwin entry point for my.*. nix-darwin supports users.users.<n>.packages
# (per-user profiles precede the system profile in PATH), so the system +
# per-user logic is shared with NixOS via ./system-scope.nix, and fish's nix-env
# system wiring is shared via ./fish-system.nix.
{...}: {
  imports = [
    ./system-scope.nix
    ./fish-system.nix
  ];
}
