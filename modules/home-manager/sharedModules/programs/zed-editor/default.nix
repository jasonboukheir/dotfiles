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
      # mutableUserKeymaps = false;
      # mutableUserSettings = false;
      # mutableUserTasks = false;
      installRemoteServer = true;
      userSettings = lib.mkMerge [
        (import
          ./ssh_connections.nix)
        {
          load_direnv = "shell_hook";
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
                  code_action = "source.fixAll.ruff";
                }
                {
                  code_action = "source.organizeImports.ruff";
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
