# System-scope install plumbing for the package-only my.zmx: the overlay
# package lands on every user's PATH (with its generated shell completions)
# via environment.systemPackages.
{
  pkgs,
  inputs ? null,
}: let
  pkgsZmx = pkgs.extend (import ../../nixpkgs/overlays/zmx.nix);
in
  pkgs.testers.nixosTest {
    name = "my-zmx-install";

    nodes.machine = {
      nixpkgs.pkgs = pkgsZmx;
      imports = [../nixos.nix];

      my.zmx.enable = true;

      users.users.tester = {
        isNormalUser = true;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("zmx is on a normal user's PATH and runs"):
          machine.succeed("su -l tester -c 'command -v zmx'")
          machine.succeed("su -l tester -c 'zmx completions bash' | grep -q zmx")
    '';
  }
