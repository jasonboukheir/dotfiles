{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.nvf.settings.vim.theme;
in {
  options = {
    cfg.nord-nvim.enable = mkEnableOption "nord nvim theme";
  };
  config = mkIf cfg.nord-nvim.enable {
    programs.nvf.settings.vim.extraPlugins.nord-nvim = {
      package = pkgs.vimPlugins.nord-nvim;
      setup = "vim.cmd.colorscheme('nord')";
    };
  };
}
