# The helium External Extensions carve-out (../helium.nix): tmpfiles seeds the
# fixed-path manifests under ~/.config/net.imput.helium for jasonbk, and —
# being seed-and-accept — never clobbers a manifest Helium has since rewritten.
# my.helium.package is stubbed so the test doesn't fetch the real browser.
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

    extensions_dir = "/home/jasonbk/.config/net.imput.helium/External Extensions"
    extension_ids = [
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa",
        "dphilobhebphkdjbpfohgikllaljmgbn",
    ]

    machine.wait_for_unit("multi-user.target")

    with subtest("tmpfiles seeds a manifest per extension, owned by jasonbk"):
        for ext_id in extension_ids:
            manifest = f"{extensions_dir}/{ext_id}.json"
            machine.succeed(f"test -f '{manifest}'")
            machine.succeed(f"[ \"$(stat -c %U:%a '{manifest}')\" = jasonbk:644 ]")
            content = json.loads(machine.succeed(f"cat '{manifest}'"))
            assert content["external_update_url"] == (
                "https://clients2.google.com/service/update2/crx"
            ), f"unexpected manifest content: {content!r}"
        machine.succeed(f"[ \"$(stat -c %U '{extensions_dir}')\" = jasonbk ]")

    with subtest("seeding is seed-and-accept: a rewritten manifest is left alone"):
        manifest = f"{extensions_dir}/{extension_ids[0]}.json"
        machine.succeed(f"su -l jasonbk -c 'echo helium-owns-this > \"{manifest}\"'")
        machine.succeed("systemd-tmpfiles --create")
        machine.succeed(f"grep -q helium-owns-this '{manifest}'")

    with subtest("my.helium installs the (stubbed) browser on jasonbk's PATH"):
        machine.succeed("su -l jasonbk -c 'helium' | grep -q helium-stub")
  '';
}
