# my.helium.extensions must reach Helium through the channel its
# ungoogled-chromium base honors: a Chromium ExtensionInstallForcelist managed
# policy under /etc/chromium/policies/managed (../helium.nix), rendered by the
# framework's `etc` hook from a per-user scope. my.helium.package is stubbed so
# the test doesn't fetch the real browser.
{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-helium-extensions";

  nodes.machine = {pkgs, ...}: {
    imports = [
      ../helium.nix
      ../../../modules/my/nixos.nix
      ../../../modules/nixos/programs/_1password.nix
    ];

    _module.args = {inherit inputs;};

    users.users.jasonbk = {
      isNormalUser = true;
    };

    users.users.jasonbk.my.helium.package = pkgs.writeShellScriptBin "helium" ''
      echo helium-stub
    '';
  };

  testScript = ''
    import json

    policy = "/etc/chromium/policies/managed/helium-extensions.json"
    extension_ids = [
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa",
        "dphilobhebphkdjbpfohgikllaljmgbn",
    ]

    machine.wait_for_unit("multi-user.target")

    with subtest("a per-user my.helium.extensions list renders a system forcelist policy"):
        machine.succeed(f"test -f '{policy}'")
        content = json.loads(machine.succeed(f"cat '{policy}'"))
        assert content["ExtensionInstallForcelist"] == extension_ids, (
            f"unexpected forcelist: {content!r}"
        )

    with subtest("my.helium installs the (stubbed) browser on jasonbk's PATH"):
        machine.succeed("su -l jasonbk -c 'helium' | grep -q helium-stub")
  '';
}
