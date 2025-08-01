{ inputs, ... }:
{
  home-manager.users.jasonbk = {
    imports = [ inputs.nvf.homeManagerModules.default ];
    programs.nvf = {
      enable = true;
      settings = {
        vim.viAlias = true;
        vim.vimAlias = true;
        vim.lsp = {
          enable = true;
        };
        vim.treesitter = {
          enable = true;
        };
        vim.theme = {
          enable = true;
          name = "nord";
        };
        vim.luaConfigRC.myConfig = # lua
          ''
            vim.opt.tabstop = 2
            vim.opt.shiftwidth = 2
            vim.opt.softtabstop = 2
            vim.opt.expandtab = true
          '';
      };
    };
  };
}
