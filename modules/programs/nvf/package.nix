# Generate a wrapped neovim package from nvf's standalone builder. Pure tooling:
# given a host's `neovimConfiguration` (the nvf flake input differs per
# partition) and a list of nvf modules, return the built `neovim` derivation.
{
  pkgs,
  neovimConfiguration,
  modules,
}:
(neovimConfiguration {
  inherit pkgs modules;
})
.neovim
