{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    git
    neovim
    # Hyprland's safe mode binds SUPER+Q to the first of a hardcoded list
    # (kitty/alacritty/foot/wezterm/gnome-terminal/xterm) and never reads
    # $TERMINAL, so ghostty is unreachable there. foot is Wayland-native and
    # tiny; ship it purely as the recoverable terminal when a crashed session
    # relaunches into safe mode.
    foot
  ];
}
