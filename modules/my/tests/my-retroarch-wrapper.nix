# Per-user plumbing: my.retroarch.{cores,settings} -> retroarch-with-cores
# wrapper with the cores' .so files on -L and a baked declarative cfg.
{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "my-retroarch-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.retroarch = {
          enable = true;
          cores = ["nestopia"];
          settings = {
            video_driver = "vulkan";
            config_save_on_exit = false;
          };
        };
      };
    };

    testScript = {nodes, ...}: let
      finalPackage = nodes.machine.users.users.tester.my.retroarch.finalPackage;
    in ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the wrapped retroarch is in the user's environment and runs"):
          path = machine.succeed(
              "su -l tester -c 'readlink -f \"$(command -v retroarch)\"'"
          ).strip()
          assert path.startswith("${finalPackage}"), f"retroarch resolves outside the wrapper: {path}"
          machine.succeed("su -l tester -c 'retroarch --version'")

      with subtest("the configured core is baked into the wrapper's cores dir"):
          machine.succeed("test -e ${finalPackage}/lib/retroarch/cores/nestopia_libretro.so")

      with subtest("the binary wrapper points -L at the baked cores dir"):
          machine.succeed(
              "grep -aq -- '-L ${finalPackage}/lib/retroarch/cores' ${finalPackage}/bin/retroarch"
          )

      with subtest("settings land in the baked declarative cfg, bools stringified"):
          # Charset-restricted so the match can't greedily span the NUL
          # separators between the C wrapper's embedded argv strings.
          cfg_path = machine.succeed(
              "grep -aoh '/nix/store/[A-Za-z0-9._+-]*-declarative-retroarch.cfg' ${finalPackage}/bin/retroarch | head -n1"
          ).strip()
          cfg = machine.succeed(f"cat {cfg_path}")
          assert 'video_driver = "vulkan"' in cfg, f"video_driver not baked: {cfg!r}"
          assert 'config_save_on_exit = "false"' in cfg, f"bool not stringified: {cfg!r}"
    '';
  }
