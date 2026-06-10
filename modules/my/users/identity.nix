# Per-user VCS identity (name/email), a module-merge onto the users.users.<name>
# submodule. The my.{git,jujutsu} program defs map it into their user.{name,email}
# settings via `settingsDefaults` (injected below mkDefault), so the same person
# isn't spelled out once per tool.
{lib, ...}: {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.identity = {
        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "Jason Elie Bou Kheir";
          description = ''
            Full name baked into this user's VCS wrappers (git/jujutsu
            `user.name`). Deliberately separate from `users.users.<name>.description`
            (GECOS) so the committer name can differ from the login account's.
          '';
        };

        email = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "you@example.com";
          description = "Email baked into this user's VCS wrappers (git/jujutsu `user.email`).";
        };
      };
    });
  };
}
