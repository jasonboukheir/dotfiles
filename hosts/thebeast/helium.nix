# Helium from helium-flake's overlay, installed on jasonbk's profile via
# my.helium. The fixed-path External Extensions manifests under
# ~/.config/net.imput.helium are an accepted-manual carve-out (#50): tmpfiles
# seeds each manifest only when it's missing (`C`, no `+`), and Helium owns
# the directory afterwards.
{
  config,
  inputs,
  pkgs,
  ...
}: let
  extensionIds = [
    "aeblfdkhhhdcdjpifhhbdiojplfjncoa"
    "dphilobhebphkdjbpfohgikllaljmgbn"
  ];
  externalExtension = pkgs.writeText "helium-external-extension.json" (builtins.toJSON {
    external_update_url = "https://clients2.google.com/service/update2/crx";
  });
  home = config.users.users.jasonbk.home;
  extensionsDir = "${home}/.config/net.imput.helium/External Extensions";
in {
  nixpkgs.overlays = [
    inputs.helium-flake.overlays.default
  ];

  users.users.jasonbk.my.helium.enable = true;

  # Trust helium for the 1Password GUI browser integration
  # (modules/nixos/programs/_1password.nix renders this into /etc/1password).
  programs._1password-gui.customAllowedBrowsers = ["helium"];

  # ':' = apply mode/owner only on creation, so existing user dirs are never
  # chmod/chowned out from under jasonbk.
  systemd.tmpfiles.rules =
    [
      "d '${home}/.config' :0700 :jasonbk :users -"
      "d '${home}/.config/net.imput.helium' :0700 :jasonbk :users -"
      "d '${extensionsDir}' :0700 :jasonbk :users -"
    ]
    ++ map (id: "C '${extensionsDir}/${id}.json' 0644 jasonbk users - ${externalExtension}") extensionIds;
}
