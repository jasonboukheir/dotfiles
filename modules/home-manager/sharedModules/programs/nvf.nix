{
  pkgs,
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.nvf.enable {
    programs.nvf.settings = {
      vim = {
        autocomplete.blink-cmp = {
          enable = true;
        };
        viAlias = true;
        vimAlias = true;
        lsp = {
          enable = true;
          formatOnSave = true;
        };
        telescope = {
          enable = true;
          extensions = [
            {
              name = "fzf";
              packages = [pkgs.vimPlugins.telescope-fzf-native-nvim];
              setup = {fzf = {fuzzy = true;};};
            }
          ];
        };
        treesitter.enable = true;
        theme = {
          enable = true;
          name = "nord";
        };
        options = {
          tabstop = 2;
          shiftwidth = 2;
          softtabstop = 2;
          expandtab = true;
        };
        utility.oil-nvim.enable = true;
        languages = {
          enableFormat = true;
          enableTreesitter = true;
          nix.enable = true;
          nu.enable = true;
          python.enable = true;
          zig.enable = true;
        };
      };
    };
  };
}
