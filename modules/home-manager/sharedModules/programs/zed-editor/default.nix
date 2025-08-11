{
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkIf config.programs.zed-editor.enable {
    programs.zed-editor = {
      extensions = [
        "csharp"
        "git-firefly"
        "nix"
        "nu"
        "zig"
        "ruff"
      ];
      installRemoteServer = true;
      themes = {
        "Nord" = ./themes/nord.json;
      };
      userSettings = lib.mkMerge [
        {
          ui_font_size = 14;
          buffer_font_family = "FiraCode Nerd Font";
          buffer_font_size = 14;
          theme = {
            mode = "system";
            light = "Nord Light";
            dark = "Nord";
          };
          vim_mode = true;
          languages = {
            "Nix" = {
              language_servers = ["nixd" "!nil"];
              formatter = {
                external = {
                  arguments = ["--quiet" "--"];
                  command = "alejandra";
                };
              };
            };
            "Python" = {
              language_servers = [
                "pyright"
                "ruff"
              ];
              format_on_save = "on";
              formatter = [
                {
                  code_actions = {
                    "source.organizeImports.ruff" = true;
                    "source.fixAll.ruff" = true;
                  };
                }
                {
                  language_server.name = "ruff";
                }
              ];
            };
          };
        }
        (lib.mkIf config.programs.direnv.enable {
          load_direnv = "shell_hook";
        })
      ];
    };
  };
}
