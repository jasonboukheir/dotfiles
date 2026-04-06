{
  pkgs-unstable,
  lib,
  ...
}: {
  programs.claude-code = {
    package = lib.mkDefault pkgs-unstable.claude-code;
    memory.text = ''
      RULE: Self-documenting code instead of comments
    '';
    settings = {
      effortLevel = "high";
      permissions = {
        defaultMode = "acceptEdits";
      };
    };
  };
}
