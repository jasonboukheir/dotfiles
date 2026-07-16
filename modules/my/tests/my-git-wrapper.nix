# Per-user plumbing: my.git.{settings,lfs} -> GIT_CONFIG_GLOBAL + git-lfs on PATH.
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-git-wrapper-9c2e";
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-git-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.git = {
          enable = true;
          lfs.enable = true;
          settings.wrapper.sentinel = sentinel;
          ssh = {
            agentSocket = "/tmp/my-git-agent.sock";
            match = "Host github.com";
            identityFiles = [
              "/tmp/my-git-cert.pub"
              "/tmp/my-git-key.pub"
            ];
            identitiesOnly = true;
            extraOptions.PreferredAuthentications = "publickey";
          };
          signing.ssh = {
            enable = true;
            key = "/tmp/my-git-signing-key.pub";
            allowedSignersFile = "/tmp/my-git-allowed-signers";
          };
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped git is in the user's environment and runs"):
          machine.succeed("su -l tester -c 'git --version'")

      with subtest("the wrapper loads the user's baked GIT_CONFIG_GLOBAL"):
          got = machine.succeed(
              "su -l tester -c 'git config --global --get wrapper.sentinel'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not load baked config: {got!r}"

          got = machine.succeed(
              "su -l tester -c 'GIT_CONFIG_GLOBAL=/dev/null git config --global --get wrapper.sentinel'"
          ).strip()
          assert got == "${sentinel}", f"wrapper did not pin GIT_CONFIG_GLOBAL: {got!r}"

      with subtest("git-lfs rides on the wrapper PATH and its filter is baked in"):
          machine.succeed("su -l tester -c 'git lfs version'")
          required = machine.succeed(
              "su -l tester -c 'git config --global --get filter.lfs.required'"
          ).strip()
          assert required == "true", f"lfs filter not baked: {required!r}"

      with subtest("ssh auth and signing options are baked into the wrapper"):
          signing_key = machine.succeed(
              "su -l tester -c 'git config --global --get user.signingKey'"
          ).strip()
          assert signing_key == "/tmp/my-git-signing-key.pub", f"signing key not baked: {signing_key!r}"

          signer = machine.succeed(
              "su -l tester -c 'git config --global --get gpg.ssh.program'"
          ).strip()
          assert signer.endswith("/bin/my-git-ssh-sign"), f"unexpected signer: {signer!r}"
          machine.succeed(f"grep -q /tmp/my-git-agent.sock {signer}")

          wrapper = machine.succeed(
              "su -l tester -c 'readlink -f $(command -v git)'"
          ).strip()
          body = machine.succeed(f"cat {wrapper}")
          assert "GIT_SSH_COMMAND" in body, f"GIT_SSH_COMMAND not set in wrapper: {body!r}"
          assert "SSH_AUTH_SOCK" in body and "/tmp/my-git-agent.sock" in body, (
              f"SSH_AUTH_SOCK not pinned in wrapper: {body!r}"
          )

          ssh_config = machine.succeed(
              f"grep -aoE '/nix/store/[a-z0-9]{{32}}-git-ssh-config' {wrapper} | head -n1"
          ).strip()
          rendered = machine.succeed(f"cat {ssh_config}")
          assert "Host github.com" in rendered, f"ssh match not rendered: {rendered!r}"
          assert 'IdentityAgent "/tmp/my-git-agent.sock"' in rendered, (
              f"identity agent not rendered: {rendered!r}"
          )
          assert 'IdentityFile "/tmp/my-git-cert.pub"' in rendered, (
              f"cert identity not rendered: {rendered!r}"
          )
          assert "IdentitiesOnly yes" in rendered, f"identities-only not rendered: {rendered!r}"
    '';
  }
