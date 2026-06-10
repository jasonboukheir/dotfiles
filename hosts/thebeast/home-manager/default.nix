{...}: {
  imports = [
    ./sharedModules
  ];
  home-manager.users.jasonbk.imports = [./jasonbk];
  # gamer gets the omarchy HM sharedModules too: steamos-manager's
  # Switch-to-Desktop can only ever land on the autologin user (see
  # hosts/thebeast/tests/steamos-autologin.nix, #48), so the Hyprland
  # session config must live on gamer. The stack used to be unsafe to
  # share — HM services like hyprpolkitagent started inside the Plasma
  # session and core-dumped — but those are native units gated on
  # omarchy.sessionTarget now; what remains in HM is config files that
  # are inert outside a Hyprland session.
  home-manager.users.gamer.imports = [./gamer];
}
