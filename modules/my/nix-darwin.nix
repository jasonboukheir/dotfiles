# nix-darwin entry point for the my.* surface. nix-darwin supports both
# environment.systemPackages and users.users.<n>.packages (per-user profiles
# under /etc/profiles/per-user/<name>, which precede the system profile in PATH),
# so the system+per-user logic is shared with NixOS via ./system-scope.nix.
{...}: {
  imports = [./system-scope.nix];
}
