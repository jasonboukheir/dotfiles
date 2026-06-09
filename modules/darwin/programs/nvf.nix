# Both macs build nvf from the darwin nvf input. mkDefault so a host can opt out
# (e.g. work-macbook, which builds neovim through the my.nvf wrapper instead).
{
  inputs,
  lib,
  ...
}: {
  programs.nvf = {
    enable = lib.mkDefault true;
    neovimConfiguration = inputs.nvf-darwin.lib.neovimConfiguration;
  };
}
