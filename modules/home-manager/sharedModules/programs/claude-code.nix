{...}: {
  programs.claude-code = {
    memory.text = ''
      RULE: Self-documenting code instead of comments
    '';
    settings = {
      permissions = {
        defaultMode = "acceptEdits";
      };
    };
  };
}
