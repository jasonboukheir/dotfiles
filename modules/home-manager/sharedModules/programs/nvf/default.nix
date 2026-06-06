{
  pkgs,
  config,
  lib,
  ...
}: let
  stylixEnabled = config ? stylix && config.stylix.enable;
  stylixPolarity = lib.optionalString stylixEnabled config.stylix.polarity;
in {
  config = lib.mkIf config.programs.nvf.enable {
    programs.nvf.settings = {
      lib,
      options,
      ...
    }: let
      hasTomlLanguage = lib.hasAttrByPath ["vim" "languages" "toml" "enable"] options;
    in {
      vim = lib.mkMerge [
        (lib.mkIf stylixEnabled {
          luaConfigRC.background = lib.nvim.dag.entryBefore ["theme"] ''
            vim.o.background = "${stylixPolarity}"
          '';
        })
        {
          autocomplete.blink-cmp = {
            enable = true;
          };
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
  };
}
