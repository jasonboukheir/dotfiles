{lib, ...}: {
  imports = [
    ./gnome.nix
    ./kde.nix
    ./evolution.nix
    ./terminal.nix
  ];
  options.omarchy = {
    pim = lib.mkOption {
      type = lib.types.enum ["gnome" "kde" "evolution" "terminal"];
      default = "gnome";
      description = "The calendar (ical) suite to use";
    };
  };
}
