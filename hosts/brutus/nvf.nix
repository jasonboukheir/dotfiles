{inputs, ...}: {
  programs.nvf = {
    enable = true;
    neovimConfiguration = inputs.nvf-nixos.lib.neovimConfiguration;
  };
}
