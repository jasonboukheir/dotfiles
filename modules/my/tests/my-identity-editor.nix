# Per-user plumbing: users.users.<n>.{identity,editor} -> the my.{git,gh,jujutsu}
# wrappers default their user.{name,email} and editor fields from it.
{
  pkgs,
  inputs ? null,
}: let
  # Named nvim so the vim-family merge/diff tool mapping in the defs fires.
  editor = pkgs.writeShellScriptBin "nvim" "exit 0";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-identity-editor";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        identity = {
          name = "Test Person";
          email = "test@example.com";
        };
        inherit editor;
        my.git.enable = true;
        my.gh.enable = true;
        my.jujutsu.enable = true;
      };

      users.users.blank = {
        isNormalUser = true;
        my.git.enable = true;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("identity defaults git's user.{name,email}"):
          for key, want in [("user.name", "Test Person"), ("user.email", "test@example.com")]:
              got = machine.succeed(
                  f"su -l tester -c 'git config --global --get {key}'"
              ).strip()
              assert got == want, f"git {key} not defaulted from identity: {got!r}"

      with subtest("editor defaults git's editor and vim-family merge/diff tools"):
          for key, want in [
              ("core.editor", "${pkgs.lib.getExe editor}"),
              ("merge.tool", "nvimdiff"),
              ("mergetool.nvimdiff.path", "${pkgs.lib.getExe editor}"),
              ("diff.tool", "nvimdiff"),
              ("difftool.nvimdiff.path", "${pkgs.lib.getExe editor}"),
          ]:
              got = machine.succeed(
                  f"su -l tester -c 'git config --global --get {key}'"
              ).strip()
              assert got == want, f"git {key} not defaulted from editor: {got!r}"

      with subtest("a user without identity gets no user.* baked into git"):
          machine.fail("su -l blank -c 'git config --global --get user.name'")
          listed = machine.succeed("su -l blank -c 'git config --global --list'")
          assert "user." not in listed, f"unexpected user.* in blank's gitconfig: {listed!r}"

      with subtest("identity defaults jj's user.{name,email}"):
          for key, want in [("user.name", "Test Person"), ("user.email", "test@example.com")]:
              got = machine.succeed(f"su -l tester -c 'jj config get {key}'").strip()
              assert got == want, f"jj {key} not defaulted from identity: {got!r}"

      with subtest("editor defaults jj's editor and vim-family merge tool"):
          for key, want in [
              ("ui.editor", "${pkgs.lib.getExe editor}"),
              ("ui.merge-editor", "vimdiff"),
              ("merge-tools.vimdiff.program", "${pkgs.lib.getExe editor}"),
          ]:
              got = machine.succeed(f"su -l tester -c 'jj config get {key}'").strip()
              assert got == want, f"jj {key} not defaulted from editor: {got!r}"

      with subtest("editor defaults gh's baked GH_EDITOR"):
          gh = machine.succeed("su -l tester -c 'readlink -f $(command -v gh)'").strip()
          machine.succeed(f"grep -aq '${pkgs.lib.getExe editor}' {gh}")
    '';
  }
