{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
in
  pkgs.testers.nixosTest {
    name = "shell-init-hooks";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [
        ../fish.nix
        ../direnv.nix
        ../starship.nix
      ];

      users.users.tester = {
        isNormalUser = true;
        shell = pkgs.fish;
        programs.starship.enable = true;
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("native fish runs"):
          machine.succeed("su -l tester -c 'fish -c \"echo ok\"'")

      with subtest("the HM-replacing shell-init hooks are concatenated into the fish config"):
          cfg = machine.succeed("readlink -f /etc/fish/config.fish").strip()
          machine.succeed(f"grep -q 'starship init fish' {cfg}")
          machine.succeed(f"grep -q 'direnv hook fish' {cfg}")

      with subtest("the plugin-git vendor functions load in fish"):
          machine.succeed("su -l tester -c 'fish -c \"functions -q grt\"'")

      with subtest("the per-user starship wrapper resolves and initializes for fish"):
          machine.succeed("su -l tester -c 'starship init fish'")

      with subtest("native direnv + nix-direnv is available"):
          machine.succeed("su -l tester -c 'direnv version'")
    '';
  }
