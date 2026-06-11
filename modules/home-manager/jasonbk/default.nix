{
  lib,
  options,
  ...
}: {
  # Inert on home-manager-free hosts (thebeast, #57); see ../default.nix.
  config = lib.optionalAttrs (options ? home-manager) {
    home-manager.users.jasonbk.imports = [
      ./programs
    ];
  };
}
