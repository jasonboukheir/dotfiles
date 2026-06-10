# Per-user plumbing: my.claude-code.settings -> a baked --settings file (layered
# over the writable ~/.claude), system polarity -> the `theme` key, and
# package = null -> install nothing (preinstalled-claude hosts). A stub package
# stands in for claude-code so the test never builds the real node closure.
{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
  sentinel = "my-claude-code-defaultMode-7c2e";
  stubClaude = pkgsWrapped.writeShellScriptBin "claude" ''exec true "$@"'';

  colors = {
    base00 = "010203";
    base05 = "101112";
  };
in
  pkgs.testers.nixosTest {
    name = "my-claude-code-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [
        ../nixos.nix
        ../../stylix/users/options.nix
      ];

      users.users.tester = {
        isNormalUser = true;
        stylix = {
          enable = true;
          polarity = "dark";
          inherit colors;
        };
        my.stylix.enable = true;
        my.claude-code = {
          enable = true;
          package = stubClaude;
          settings.permissions.defaultMode = sentinel;
        };
      };

      # A second user whose claude is "preinstalled" (package = null): my.* must
      # install nothing, so no wrapped claude lands on this user's PATH.
      users.users.preinstalled = {
        isNormalUser = true;
        my.claude-code = {
          enable = true;
          package = null;
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      claude = machine.succeed("su -l tester -c 'readlink -f $(command -v claude)'").strip()

      with subtest("the wrapped claude is on PATH and runs"):
          machine.succeed("su -l tester -c 'claude --version || true'")

      with subtest("the wrapper injects a baked --settings file"):
          machine.succeed(f"grep -aq -- '--settings' {claude}")

      settings = machine.succeed(
          f"grep -aoE '/nix/store/[a-z0-9]{{32}}-claude-code-settings.json' {claude} | head -n1"
      ).strip()
      assert settings, "no baked settings path found in the wrapper"

      with subtest("settings sentinel and stylix theme land in the baked settings"):
          machine.succeed(f"grep -aq '${sentinel}' {settings}")
          machine.succeed(f"grep -aq 'dark-ansi' {settings}")

      with subtest("package = null installs nothing (preinstalled claude owns PATH)"):
          machine.fail("su -l preinstalled -c 'command -v claude'")
    '';
  }
