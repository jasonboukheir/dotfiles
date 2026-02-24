{...}: {
  programs.vscode-fb = {
    enable = true;
    userSettings = {
      "editor.cursorBlinking" = "phase";
      "editor.cursorStyle" = "underline";
    };
  };
}
