{...}: {
  # ghostty is the first per-user stylix target; more targets re-baking what
  # HM-stylix used to emit land with their module wrappers:
  #   claude-code (polarity -> dark-ansi/light-ansi):
  #     https://github.com/jasonboukheir/dotfiles/issues/45
  #   nvf (base16 scheme):
  #     https://github.com/jasonboukheir/dotfiles/issues/43
  #   btop / waybar / mako / wofi:
  #     https://github.com/jasonboukheir/dotfiles/issues/48
  # Tracked under https://github.com/jasonboukheir/dotfiles/issues/38
  imports = [
    ./options.nix
    ./ghostty.nix
  ];
}
