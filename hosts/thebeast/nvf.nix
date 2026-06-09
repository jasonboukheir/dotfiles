{inputs, ...}: {
  programs.nvf = {
    enable = true;
    neovimConfiguration = inputs.nvf-nixos-unstable.lib.neovimConfiguration;
  };
}
