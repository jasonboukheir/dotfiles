{...}: {
  # Darwin keeps bash in environment.shells; previously enabled as a side-effect
  # of the now-removed system-level programs.nushell.
  programs.bash.enable = true;
}
