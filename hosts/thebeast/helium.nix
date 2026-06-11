# Helium from helium-flake's overlay, installed on jasonbk's profile via
# my.helium. Extensions are force-installed through my.helium.extensions, which
# the my framework renders into /etc/chromium/policies/managed as an
# ExtensionInstallForcelist managed policy — Helium's ungoogled-chromium base
# ignores the per-profile External Extensions install path, so this (not
# user-profile seeding) is the channel that actually installs them.
{
  inputs,
  ...
}: {
  nixpkgs.overlays = [
    inputs.helium-flake.overlays.default
  ];

  users.users.jasonbk.my.helium = {
    enable = true;
    extensions = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "dphilobhebphkdjbpfohgikllaljmgbn" # SimpleLogin
    ];
  };

  # Trust helium for the 1Password GUI browser integration
  # (modules/nixos/programs/_1password.nix renders this into /etc/1password).
  programs._1password-gui.customAllowedBrowsers = ["helium"];
}
