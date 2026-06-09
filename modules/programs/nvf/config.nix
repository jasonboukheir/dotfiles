# Applies the options: assembles the nvf settings (the shared config body fed
# the stylix polarity and meta toggle, plus whatever the module system collected
# into `programs.nvf.settings` — notably stylix's nvf target) and builds the
# wrapped neovim package. Shared by the system and home-manager entry points;
# each of those installs `finalPackage` into its respective package set.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.nvf;

  # Stylix feeds the background polarity (#38). Guarded so a host without stylix
  # is a no-op rather than an eval error.
  stylix =
    if config ? stylix
    then config.stylix
    else {};
  stylixEnabled = stylix.enable or false;
  polarity = stylix.polarity or "dark";

  # The nvf module body, fed to `lib.neovimConfiguration`. Its `lib`/`pkgs`/
  # `options` are nvf's own module args (so `lib.nvim.dag` resolves), shadowing
  # the system/HM ones above.
  settings = {
    lib,
    pkgs,
    options,
    ...
  }: let
    hasTomlLanguage = lib.hasAttrByPath ["vim" "languages" "toml" "enable"] options;
  in {
    vim = lib.mkMerge [
      (lib.mkIf stylixEnabled {
        # base16 colours come from stylix's own nvf target (fed into
        # `programs.nvf.settings`); only the polarity needs feeding by hand.
        luaConfigRC.background = lib.nvim.dag.entryBefore ["theme"] ''
          vim.o.background = "${polarity}"
        '';
      })
      (lib.mkIf cfg.meta.enable {
        luaConfigRC.meta-nvim = lib.nvim.dag.entryAfter ["telescope"] ''
          local meta_plugin_path = "${cfg.meta.pluginPath}"
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
      })
      {
        autocomplete.blink-cmp.enable = true;
        viAlias = true;
        vimAlias = true;

        keymaps = [
          {
            key = "-";
            mode = "n";
            action = "<cmd>Oil<CR>";
            desc = "Open parent directory";
          }
        ];
        lsp = {
          enable = true;
          formatOnSave = true;
          servers = {
            nil.init_options = {
              nix.flake.autoArchive = true;
            };
          };
        };
        mini = {
          icons.enable = true;
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
        options = {
          tabstop = 2;
          shiftwidth = 2;
          softtabstop = 2;
          expandtab = true;
        };
        diagnostics.config = {
          virtual_text = false;
          virtual_lines.current_line = true;
        };
        utility.oil-nvim.enable = true;
        languages =
          {
            enableFormat = true;
            enableTreesitter = true;
            nix = {
              enable = true;
            };
            markdown = {
              enable = true;
            };
            nu.enable = true;
            python.enable = true;
            zig.enable = true;
          }
          // lib.optionalAttrs hasTomlLanguage {
            toml.enable = true;
          };
      }
    ];
  };
in {
  config = lib.mkIf cfg.enable {
    programs.nvf.finalPackage = import ./package.nix {
      inherit pkgs;
      inherit (cfg) neovimConfiguration;
      modules = [
        settings
        cfg.settings
      ];
    };
  };
}
