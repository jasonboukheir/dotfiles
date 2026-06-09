{
  pkgs,
  neovimConfiguration,
  modules,
}:
(neovimConfiguration {
  inherit pkgs modules;
})
.neovim
