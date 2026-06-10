# hyprlang value type, shared by the hyprlang-backed my.* defs: attrsets are
# sections, lists of attrsets repeat a section, scalars are fields. The `let`
# binding makes the recursive `attrsOf`/`listOf settingsType` references resolve.
{lib}: let
  settingsType = with lib.types;
    nullOr (oneOf [
      bool
      int
      float
      str
      path
      (attrsOf settingsType)
      (listOf settingsType)
    ])
    // {description = "hyprlang value (attrsets are sections; lists of attrsets repeat a section)";};
in
  settingsType
