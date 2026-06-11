# my.helium ships the browser (nixGL-wrapped in ../default.nix). The
# fixed-path External Extensions manifests are an accepted-manual carve-out
# (#50); they stay on home.file until the standalone managed-files mechanism
# lands (#39).
{lib, ...}: let
  extensionIds = [
    "aeblfdkhhhdcdjpifhhbdiojplfjncoa"
    "dphilobhebphkdjbpfohgikllaljmgbn"
  ];
  externalExtension = id: {
    name = ".config/net.imput.helium/External Extensions/${id}.json";
    value.text = builtins.toJSON {
      external_update_url = "https://clients2.google.com/service/update2/crx";
    };
  };
in {
  my.helium.enable = true;

  home.file = lib.listToAttrs (map externalExtension extensionIds);
}
