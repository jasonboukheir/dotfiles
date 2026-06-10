# Shared rendering helpers for the hyprlang-backed my.* program defs.
{lib}: {
  toHyprlang = import ./toHyprlang.nix {inherit lib;};
  settingsType = import ./settingsType.nix {inherit lib;};
}
