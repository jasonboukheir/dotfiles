{lib, ...}: {
  imports = [
    ./gnome.nix
    ./kde.nix
    ./evolution.nix
  ];
  options.omarchy = {
    # The "terminal" leg (khal/khard/todoman/pimsync over home-manager's
    # accounts.* machinery) was dropped per issue #50 — no host uses it, and
    # porting the accounts stack off HM wasn't worth carrying for an unused
    # option.
    pim = lib.mkOption {
      type = lib.types.enum ["gnome" "kde" "evolution"];
      default = "gnome";
      description = "The calendar (ical) suite to use";
    };
  };
}
