{...}: {
  specialisation.dev.configuration = {
    system.nixos.tags = ["dev"];
    imports = [./dev];
    gaming.enable = false;
    environment.shellAliases = {
      rebuild-dev = "sudo nixos-rebuild boot --flake . && sudo /nix/var/nix/profiles/system/specialisation/dev/bin/switch-to-configuration switch";
    };
  };
}
