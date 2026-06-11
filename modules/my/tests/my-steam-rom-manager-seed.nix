# Per-user plumbing: my.steam-rom-manager.systems -> generated SRM parser
# config, seeded into ~/.config on first launch and owned by SRM afterwards
# (seed-and-accept: a relaunch must NOT clobber runtime edits).
{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
  userConfigPath = ".config/steam-rom-manager/userData/userConfigurations.json";
  # Electron handles --version before needing a display, so the wrapper's
  # seed step runs and the app exits cleanly even headless.
  launch = "su -l tester -c 'timeout 120 steam-rom-manager --version' >/dev/null 2>&1 || true";
in
  pkgs.testers.nixosTest {
    name = "my-steam-rom-manager-seed";

    nodes.machine = {config, ...}: {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      virtualisation.memorySize = 2048;

      users.users.tester = {
        isNormalUser = true;

        my.retroarch = {
          enable = true;
          cores = ["nestopia"];
        };

        # Mirrors the thebeast wiring (hosts/thebeast/session/gaming-programs.nix):
        # parser paths must point inside the user's own retroarch wrapper.
        my.steam-rom-manager = {
          enable = true;
          romDir = "/games/roms";
          retroarchPackage = config.users.users.tester.my.retroarch.finalPackage;
          systems = [
            {
              name = "NES";
              type = "retroarch";
              core = "nestopia";
              coreSo = "nestopia_libretro.so";
              dir = "nes";
              ext = ["nes" "zip"];
            }
            {
              name = "Hello";
              type = "standalone";
              pkg = "hello";
              bin = "hello";
              dir = "hello";
              ext = ["zip"];
            }
          ];
        };
      };
    };

    testScript = {nodes, ...}: let
      retroarchPackage = nodes.machine.users.users.tester.my.retroarch.finalPackage;
      jq = pkgs.lib.getExe pkgsWrapped.jq;
    in ''
      import json

      machine.wait_for_unit("multi-user.target")

      with subtest("first launch seeds userConfigurations.json"):
          machine.fail("test -e /home/tester/${userConfigPath}")
          machine.succeed("${launch}")
          parsers = json.loads(machine.succeed("${jq} . /home/tester/${userConfigPath}"))

      with subtest("the seeded parsers point at real emulator executables"):
          by_title = {p["configTitle"]: p for p in parsers}
          assert set(by_title) == {"NES", "Hello"}, f"unexpected parsers: {set(by_title)}"

          nes = by_title["NES"]
          assert nes["executable"]["path"] == "${retroarchPackage}/bin/retroarch", nes
          core_so = "${retroarchPackage}/lib/retroarch/cores/nestopia_libretro.so"
          assert core_so in nes["commandLineArguments"], nes["commandLineArguments"]
          assert nes["romDirectory"] == "/games/roms/nes", nes["romDirectory"]
          machine.succeed(f"test -x {nes['executable']['path']}")
          machine.succeed(f"test -e {core_so}")
          machine.succeed(f"test -x {by_title['Hello']['executable']['path']}")

      with subtest("the seeded file is mutable and owned by the user"):
          machine.succeed("su -l tester -c 'test -w ${userConfigPath}'")

      with subtest("a relaunch does not clobber runtime edits (seed-and-accept)"):
          machine.succeed(
              "su -l tester -c \"echo '[]' > ${userConfigPath}\""
          )
          machine.succeed("${launch}")
          kept = machine.succeed("cat /home/tester/${userConfigPath}").strip()
          assert kept == "[]", f"relaunch clobbered the user's config: {kept!r}"
    '';
  }
