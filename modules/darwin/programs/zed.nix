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

  # system.activationScripts.postActivation.text = ''
  #   if [ -f "${pkgs.zed-editor}/bin/zeditor" ]; then
  #     echo 'Symlinking Zed Editor (${pkgs.zed-editor}) to /usr/local/bin to install CLI'
  #     sudo ln -sf "${pkgs.zed-editor}/bin/zeditor" /usr/local/bin/zed
  #   else
  #     echo "Zed editor not installed, skipping symlink creation"
  #   fi
  # '';
}
