{
  pkgs-unstable,
  lib,
  options,
  ...
}: let
  claudeCodeInstructions = ''
    RULE: Self-documenting code instead of comments
  '';
  hasContextOption = lib.hasAttr "context" (options.programs.claude-code or {});
in {
  programs.claude-code =
    {
      package = lib.mkDefault pkgs-unstable.claude-code;
      settings = {
        effortLevel = "high";
        permissions = {
          defaultMode = "acceptEdits";
        };
      };
    }
    // (
      if hasContextOption
      then {context = claudeCodeInstructions;}
      else {memory.text = claudeCodeInstructions;}
    );
}
