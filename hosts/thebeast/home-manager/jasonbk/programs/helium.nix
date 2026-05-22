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
  programs.helium.enable = true;

  home.file = lib.listToAttrs (map externalExtension extensionIds);
}
