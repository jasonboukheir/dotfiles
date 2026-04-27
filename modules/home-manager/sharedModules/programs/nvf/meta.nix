{
  config,
  lib,
  ...
}: let
  cfg = config.programs.nvf.meta;
in {
  options.programs.nvf.meta = {
    enable = lib.mkEnableOption "meta.nvim plugin (Myles, BigGrep, Hg, LSP, etc.)";

    pluginPath = lib.mkOption {
      type = lib.types.str;
      default = "/usr/share/fb-editor-support/nvim";
      description = "Path to the meta.nvim plugin directory.";
    };
  };

  config = lib.mkIf (config.programs.nvf.enable && cfg.enable) {
    programs.nvf.settings = {lib, ...}: {
      vim.luaConfigRC.meta-nvim = lib.nvim.dag.entryAfter ["telescope"] ''
        local meta_plugin_path = "${cfg.pluginPath}"
        if vim.fn.isdirectory(meta_plugin_path) == 1 then
          vim.opt.rtp:prepend(meta_plugin_path)
          require("telescope").load_extension("myles")
          require("telescope").load_extension("biggrep")
          require("telescope").load_extension("hg")

          local function in_arc_project()
            return vim.fn.findfile(".arcconfig", ".;") ~= ""
          end

          vim.keymap.set("n", "<leader>ff", function()
            if in_arc_project() then
              require("telescope").extensions.myles.myles({})
            else
              require("telescope.builtin").find_files({})
            end
          end, { desc = "Find files" })

          vim.keymap.set("n", "<leader>fg", function()
            if in_arc_project() then
              require("telescope").extensions.biggrep.s({})
            else
              require("telescope.builtin").live_grep({})
            end
          end, { desc = "Grep" })

          vim.keymap.set("n", "<leader>fd", function()
            if in_arc_project() then
              require("telescope").extensions.hg.diff({})
            end
          end, { desc = "Hg diff hunks" })
        else
          vim.notify("meta.nvim: plugin path " .. meta_plugin_path .. " not found, skipping", vim.log.levels.WARN)
        end
      '';
    };
  };
}
