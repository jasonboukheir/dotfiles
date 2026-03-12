{...}: {
  programs.zed-editor = {
    enable = true;
    userSettings.window.titlebar = "custom";
    userKeymaps = [
      {
        context = "Editor";
        bindings = {
          "ctrl-c" = "editor::Copy";
          "ctrl-x" = "editor::Cut";
          "ctrl-v" = "editor::Paste";
          "ctrl-z" = "editor::Undo";
          "ctrl-shift-z" = "editor::Redo";
          "ctrl-a" = "editor::SelectAll";
          "ctrl-s" = "workspace::Save";
          "ctrl-f" = "search::Deploy";
          "ctrl-w" = "pane::CloseActiveItem";
          "ctrl-p" = "file_finder::Toggle";
          "ctrl-shift-p" = "command_palette::Toggle";
        };
      }
      {
        context = "Terminal";
        bindings = {
          "ctrl-shift-c" = "terminal::Copy";
          "ctrl-shift-v" = "terminal::Paste";
        };
      }
    ];
  };
}
