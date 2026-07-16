# Per-user plumbing: users.users.<n>.my.jujutsu.settings -> JJ_CONFIG -> jj.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-jj-wrapper-7f3a";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-jujutsu-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.jujutsu.enable = true;
        my.jujutsu.ssh.agentSocket = "/tmp/my-jj-agent.sock";
        my.jujutsu.signing.ssh = {
          enable = true;
          key = "/tmp/my-jj-signing-key.pub";
          allowedSignersFile = "/tmp/my-jj-allowed-signers";
        };
        my.jujutsu.settings.test-sentinel.value = sentinel;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped jj is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'jj --version'")

      with subtest("the wrapper loads the user's baked JJ_CONFIG"):
          got = machine.succeed(
              "su -l tester -c 'jj config get test-sentinel.value'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not load baked config: {got!r}"

          got = machine.succeed(
              "su -l tester -c 'JJ_CONFIG=/dev/null jj config get test-sentinel.value'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not pin JJ_CONFIG: {got!r}"

      with subtest("ssh auth and signing options are baked into the wrapper"):
          signing_key = machine.succeed(
              "su -l tester -c 'jj config get signing.key'"
          ).strip()
          assert signing_key == "/tmp/my-jj-signing-key.pub", f"signing key not baked: {signing_key!r}"

          signer = machine.succeed(
              "su -l tester -c 'jj config get signing.backends.ssh.program'"
          ).strip()
          assert signer.endswith("/bin/my-jj-ssh-sign"), f"unexpected signer: {signer!r}"
          machine.succeed(f"grep -q /tmp/my-jj-agent.sock {signer}")

          allowed = machine.succeed(
              "su -l tester -c 'jj config get signing.backends.ssh.allowed-signers'"
          ).strip()
          assert allowed == "/tmp/my-jj-allowed-signers", f"allowed signers not baked: {allowed!r}"

          wrapper = machine.succeed(
              "su -l tester -c 'readlink -f $(command -v jj)'"
          ).strip()
          body = machine.succeed(f"cat {wrapper}")
          assert "SSH_AUTH_SOCK" in body and "/tmp/my-jj-agent.sock" in body, (
              f"SSH_AUTH_SOCK not pinned in wrapper: {body!r}"
          )
    '';
  }
