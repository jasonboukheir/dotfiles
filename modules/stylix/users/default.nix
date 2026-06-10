{...}: {
  # Per-user stylix knobs (users.users.<name>.stylix) consumed by the my.*
  # theming cascade (modules/my/system-scope.nix). Per-app targets re-baking
  # what HM-stylix used to emit live with the my.* program defs; remaining
  # desktop targets (btop / waybar / mako / wofi) are tracked under
  # https://github.com/jasonboukheir/dotfiles/issues/48 and
  # https://github.com/jasonboukheir/dotfiles/issues/38
  imports = [
    ./options.nix
  ];
}
