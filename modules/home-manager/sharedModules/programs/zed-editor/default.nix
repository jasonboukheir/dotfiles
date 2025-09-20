{
  lib,
  config,
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
      userSettings = lib.mkMerge [
        {
          ui_font_size = 14;
          buffer_font_size = 14;
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
