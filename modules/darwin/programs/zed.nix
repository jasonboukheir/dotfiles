{ ... }:
{
  home-manager.users.jasonbk = {
    programs.zed-editor = {
      enable = true;
      extensions = [
        "csharp"
        "git-firefly"
        "nix"
        "zig"
        "ruff"
      ];
      installRemoteServer = true;
      themes = {
        "Nord" = ./zed/themes/nord.json;
      };
      userSettings = {
        ui_font_size = 14;
        buffer_font_family = "FiraCode Nerd Font";
        buffer_font_size = 14;
        theme = {
          mode = "system";
          light = "Nord Light";
          dark = "Nord";
        };
        load_direnv = "shell_hook";
        vim_mode = true;
        languages = {
          "Nix" = {
            formatter = {
              external = {
                arguments = [ ];
                command = "nixfmt";
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
      };
    };
  };
}
