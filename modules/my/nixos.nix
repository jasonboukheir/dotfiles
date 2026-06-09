# NixOS entry point for the my.* surface. Installs my.<tool> into
# environment.systemPackages (system scope) and users.users.<n>.my.<tool> into
# users.users.<n>.packages (per-user scope). The system+per-user logic is shared
# with nix-darwin via ./system-scope.nix.
{...}: {
  imports = [./system-scope.nix];
}
