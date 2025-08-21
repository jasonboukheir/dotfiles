{...}: {
  programs.nushell = {
    enable = true;
    extraEnv = builtins.readFile ./env.nu;
  };
}
