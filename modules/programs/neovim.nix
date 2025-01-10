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
      };
    };
  };
}
