{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.nvf.enable {
    programs.nvf.settings = {
      vim.viAlias = true;
      vim.vimAlias = true;
      vim.lsp = {
        enable = true;
      };
      vim.treesitter = {
        enable = true;
      };
      vim.luaConfigRC.myConfig =
        # lua
        ''
          vim.opt.tabstop = 2
          vim.opt.shiftwidth = 2
          vim.opt.softtabstop = 2
          vim.opt.expandtab = true
        '';
    };
  };
}
