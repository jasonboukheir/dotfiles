{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.nvf.enable {
    programs.nvf.settings = {
      vim = {
        viAlias = true;
        vimAlias = true;
        lsp.enable = true;
        treesitter.enable = true;
        theme = {
          enable = true;
        };
        options = {
          tabstop = 2;
          shiftwidth = 2;
          softtabstop = 2;
          expandtab = true;
        };
      };
    };
  };
}
