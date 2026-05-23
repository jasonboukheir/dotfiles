{
  pkgs,
  inputs,
}: let
  stubSession = pkgs.runCommandLocal "stub-session" {
    passthru.providedSessions = ["stub-session"];
  } ''
    mkdir -p $out/share/wayland-sessions $out/bin
    cat > $out/bin/stub-session <<EOF
    #!${pkgs.runtimeShell}
    echo "stub-session: starting pid=\$\$ user=\$USER" >&2
    exec ${pkgs.coreutils}/bin/sleep infinity
    EOF
    chmod +x $out/bin/stub-session
    cat > $out/share/wayland-sessions/stub-session.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Stub Session
    Exec=$out/bin/stub-session
    DesktopNames=stub
    EOF
  '';
in
  pkgs.testers.nixosTest {
    name = "thebeast-dm-recovery";

    nodes.machine = {
      lib,
      pkgs,
      ...
    }: {
      imports = [
        inputs.agenix.nixosModules.default
        inputs.home-manager-nixos-unstable.nixosModules.home-manager
        inputs.stylix-nixos-unstable.nixosModules.stylix
        inputs.jovian.nixosModules.default

        ../software.nix
        ../session.nix
        ./test-overrides.nix
      ];

      virtualisation = {
        memorySize = 2048;
        cores = 2;
        qemu.options = [
          "-vga std"
        ];
      };

      services.displayManager.sessionPackages = lib.mkAfter [stubSession];
      services.displayManager.defaultSession = lib.mkForce "stub-session";
      jovian.steam.desktopSession = lib.mkForce "stub-session";
      services.displayManager.autoLogin.user = lib.mkForce "gamer";
    };

    testScript = {nodes, ...}: ''
      import time

      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("plasmalogin.service")

      def dm_state():
          return machine.succeed(
              "systemctl show plasmalogin.service "
              "--property=ActiveState,SubState,NRestarts,MainPID,Result"
          ).strip()

      def loginctl_state():
          return machine.succeed("loginctl list-sessions --no-legend || true").strip()

      def journal_tail(n=80):
          return machine.succeed(
              f"journalctl -u plasmalogin.service --no-pager -n {n}"
          )

      with subtest("autologin landed in stub session"):
          # Wait for gamer to have ANY processes — pam_unix session-opened
          # alone isn't enough; we want the session command to be live.
          def gamer_procs():
              return machine.succeed(
                  "ps -u gamer -o pid=,comm=,args= 2>/dev/null || true"
              )

          end = time.time() + 90
          while time.time() < end:
              procs = gamer_procs()
              if "sleep" in procs:
                  break
              time.sleep(1)
          machine.log("gamer processes:")
          machine.log(gamer_procs())
          machine.log("after autologin:")
          machine.log(dm_state())
          machine.log(loginctl_state())
          machine.log(journal_tail(150))
          assert "sleep" in gamer_procs(), (
              "stub-session never reached the sleep — autologin did not "
              "successfully start the session command"
          )

      original_pid = machine.succeed(
          "systemctl show plasmalogin.service --property=MainPID --value"
      ).strip()
      machine.log(f"plasmalogin main pid before terminate-user: {original_pid}")

      with subtest("terminate-user gamer triggers a fresh display"):
          machine.succeed("loginctl terminate-user gamer || true")
          # Wait for the stub-session process to be gone
          machine.wait_until_succeeds(
              "! pgrep -u gamer -f stub-session", timeout=30
          )

          # Plasmalogin should NOT have restarted as a systemd unit — it
          # manages its own display lifecycle internally. If NRestarts
          # increments, that's the smoking gun: Restart=always tripped
          # the StartLimitBurst window and PLM is bouncing.
          time.sleep(3)
          new_state = dm_state()
          machine.log("after terminate-user:")
          machine.log(new_state)
          machine.log(loginctl_state())
          machine.log(journal_tail(120))

          new_pid = machine.succeed(
              "systemctl show plasmalogin.service --property=MainPID --value"
          ).strip()
          assert new_pid == original_pid, (
              f"plasmalogin main pid changed: {original_pid} -> {new_pid}; "
              "the unit restarted instead of recycling its display internally"
          )

      with subtest("PLM brought up a new display after session end"):
          # Look for the canonical sequence in the journal: a "Removing
          # display" line should be followed by "Adding new display"
          # and either "Greeter starting" (if relogin disabled) or
          # another "start auth user true ..." (if autologin re-fires).
          j = journal_tail(200)
          assert "Removing display" in j, (
              f"plasmalogin never logged display teardown:\n{j}"
          )
          assert "Adding new display" in j, (
              f"plasmalogin never logged a new display after session end:\n{j}"
          )
          # The terminate-user above happened after autologin's
          # gamescope session ran. PLM doesn't honor SDDM's
          # autoLogin.relogin=false; verify the actual behavior here.
          autologin_again = "start auth user true" in j.split("Removing display")[-1]
          greeter_started = "Greeter starting" in j.split("Removing display")[-1]
          machine.log(
              f"after session end: autologin_fired={autologin_again} "
              f"greeter_started={greeter_started}"
          )
          assert autologin_again or greeter_started, (
              "PLM did not transition to either a re-autologin or a greeter:\n"
              + j
          )

      with subtest("greeter or autologin actually became reachable"):
          # If PLM is healthy, plasmalogin-helper for either the greeter
          # user (988) or another autologin attempt for gamer will run.
          machine.wait_until_succeeds(
              "pgrep -f plasmalogin-helper", timeout=30
          )
          machine.log(loginctl_state())
    '';
  }
