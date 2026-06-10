# Shared rendering helpers for the hyprlang- and hyprlua-backed my.* program defs.
{lib}: {
  toHyprlang = import ./toHyprlang.nix {inherit lib;};
  toHyprlua = import ./toHyprlua.nix {inherit lib;};
  settingsType = import ./settingsType.nix {inherit lib;};
}
