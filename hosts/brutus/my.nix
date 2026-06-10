# my.* wrapped packages on brutus (per-user scope). claude-code's package
# defaults to master's (the claude-code-master overlay) so a new model is
# reachable ahead of unstable; theme follows system stylix polarity. ~/.claude
# and CLAUDE.md stay writable runtime state (the seed-and-accept carve-out).
{...}: {
  users.users.jasonbk.my.claude-code = {
    enable = true;
    settings = {
      autoMemoryEnabled = false;
      effortLevel = "high";
      permissions.defaultMode = "auto";
    };
  };
}
