# Generate a wrapped neovim package from nvf's standalone builder. Pure tooling:
# given a host's `neovimConfiguration` (the nvf flake input differs per
# partition, threaded in as a specialArg) and a list of nvf modules, return the
# built `neovim` derivation. Ported from modules/programs/nvf/package.nix.
{
  pkgs,
  neovimConfiguration,
  modules,
}:
(neovimConfiguration {
  inherit pkgs modules;
})
.neovim
