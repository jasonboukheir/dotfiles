# e2e for ../services/ssh-agent-switcher.nix: an outer agent (the "laptop")
# connects with agent forwarding, and inside the session a login shell must see
# the stable per-user socket — re-exported over sshd's per-connection
# SSH_AUTH_SOCK by /etc/set-environment — with the switcher proxying it to the
# freshest sshd-forwarded socket, across reconnects.
{
  pkgs,
  inputs ? null,
}:
pkgs.testers.nixosTest {
  name = "ssh-agent-switcher";

  nodes.machine = {
    imports = [../services/ssh-agent-switcher.nix];

    services.ssh-agent-switcher.users = ["tester"];
    services.openssh.enable = true;

    users.users.tester.isNormalUser = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("sshd.service")

    with subtest("it is a machine-lifetime system service: socket up before any login"):
        # The instance is wanted by multi-user.target, so it is already active
        # with its socket present before tester has ever logged in — proving the
        # daemon is not scoped to a login session (the user-service regression).
        machine.wait_for_unit("ssh-agent-switcher@tester.service")
        machine.succeed("test -S /tmp/ssh-agent.tester")

    machine.succeed('ssh-keygen -t ed25519 -N "" -f /root/key')
    machine.succeed(
        "install -d -m 700 -o tester -g users /home/tester/.ssh",
        "install -m 600 -o tester -g users /root/key.pub /home/tester/.ssh/authorized_keys",
    )

    # Outer agent with the key loaded, standing in for the laptop's agent the
    # connection forwards.
    ssh = (
        "eval $(ssh-agent) >/dev/null && ssh-add /root/key 2>/dev/null && "
        "ssh -A -i /root/key -o StrictHostKeyChecking=accept-new tester@localhost"
    )

    with subtest("a login shell sees the stable socket, not sshd's per-connection one"):
        # \$ keeps the expansion for the remote login shell: the per-connection
        # value sshd injects must be shadowed by the setEnvironment re-export.
        out = machine.wait_until_succeeds(
            ssh + " \"bash -lc 'echo SOCK=\\$SSH_AUTH_SOCK'\""
        )
        assert "SOCK=/tmp/ssh-agent.tester" in out, f"unexpected SSH_AUTH_SOCK: {out!r}"

    with subtest("the switcher proxies the stable socket to the forwarded agent"):
        out = machine.succeed(ssh + " \"bash -lc 'ssh-add -l'\"")
        assert "ED25519" in out, f"forwarded key not visible through the switcher: {out!r}"

    with subtest("the same stable socket keeps working for a new connection"):
        out = machine.succeed(
            ssh + " \"bash -lc 'ssh-add -l && echo SOCK=\\$SSH_AUTH_SOCK'\""
        )
        assert "ED25519" in out and "SOCK=/tmp/ssh-agent.tester" in out, (
            f"stable socket broke across reconnect: {out!r}"
        )

    with subtest("the daemon self-heals on a clean kill (Restart=always)"):
        # SIGTERM exits the daemon cleanly; only Restart=always (not on-failure)
        # brings it back. This is the regression that left the host without an
        # agent socket after a stray stop.
        machine.succeed("rm -f /tmp/ssh-agent.tester")
        machine.succeed("systemctl kill --signal=SIGTERM ssh-agent-switcher@tester.service")
        machine.wait_until_succeeds("test -S /tmp/ssh-agent.tester")
        out = machine.succeed(ssh + " \"bash -lc 'ssh-add -l'\"")
        assert "ED25519" in out, f"agent unreachable after self-heal: {out!r}"
  '';
}
