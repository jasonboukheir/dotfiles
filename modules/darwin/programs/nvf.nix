# Both macs build nvf from the darwin nvf input. work-macbook layers the FB
# meta.nvim pluginPath on top (hosts/work-macbook).
{inputs, ...}: {
  programs.nvf = {
    enable = true;
    neovimConfiguration = inputs.nvf-darwin.lib.neovimConfiguration;
  };
}
