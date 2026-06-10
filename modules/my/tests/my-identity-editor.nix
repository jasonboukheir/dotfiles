# Per-user plumbing: users.users.<n>.{identity,editor} -> the my.{git,gh,jujutsu}
# wrappers default their user.{name,email} and editor fields from it.
{
  pkgs,
  inputs ? null,
}: let
  editor = pkgs.writeShellScriptBin "fake-editor" "exit 0";
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
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("identity defaults git's user.{name,email}"):
          for key, want in [("user.name", "Test Person"), ("user.email", "test@example.com")]:
              got = machine.succeed(
                  f"su -l tester -c 'git config --global --get {key}'"
              ).strip()
              assert got == want, f"git {key} not defaulted from identity: {got!r}"

      with subtest("editor defaults git's editor fields to the package's exe"):
          for key in ["core.editor", "merge.tool", "diff.tool"]:
              got = machine.succeed(
                  f"su -l tester -c 'git config --global --get {key}'"
              ).strip()
              assert got == "${pkgs.lib.getExe editor}", f"git {key} not defaulted from editor: {got!r}"

      with subtest("identity defaults jj's user.{name,email}"):
          for key, want in [("user.name", "Test Person"), ("user.email", "test@example.com")]:
              got = machine.succeed(f"su -l tester -c 'jj config get {key}'").strip()
              assert got == want, f"jj {key} not defaulted from identity: {got!r}"

      with subtest("editor defaults jj's ui.{editor,merge-editor}"):
          for key in ["ui.editor", "ui.merge-editor"]:
              got = machine.succeed(f"su -l tester -c 'jj config get {key}'").strip()
              assert got == "${pkgs.lib.getExe editor}", f"jj {key} not defaulted from editor: {got!r}"

      with subtest("editor defaults gh's baked GH_EDITOR"):
          gh = machine.succeed("su -l tester -c 'readlink -f $(command -v gh)'").strip()
          machine.succeed(f"grep -aq '${pkgs.lib.getExe editor}' {gh}")
    '';
  }
