# jasonbk's platform-independent VCS identity, imported by every host through
# modules/default.nix. The my.* framework (modules/my/users/identity.nix) folds
# these into git/jujutsu/gh user.{name,email} via settingsDefaults, so the
# commit identity lives in exactly one place instead of per host.
#
# email is a real address on an owned domain, kept stable across GitHub,
# Codeberg, and Forgejo: add and verify it on each forge so commits attribute to
# the right account. GitHub blocks SimpleLogin's public alias domains as
# disposable, so a relay alias can't be verified there — hence a real mailbox.
# It is public in commit metadata by design. mkDefault lets an individual host
# override it (e.g. a work address) while keeping this the shared default.
{lib, ...}: {
  users.users.jasonbk.identity = {
    name = lib.mkDefault "Jason Elie Bou Kheir";
    email = lib.mkDefault "jasonbk@sunnycareboo.com";
  };
}
