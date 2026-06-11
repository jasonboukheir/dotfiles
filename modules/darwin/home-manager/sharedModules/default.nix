{
  inputs,
  lib,
  options,
  ...
}: {
  # Inert on home-manager-free darwin hosts (work-macbook, #55); mirrors the
  # guard in modules/home-manager/*. The mac-app-util darwin module still ships
  # via mkHost, so PATH/Dock app handling is unaffected.
  config = lib.optionalAttrs (options ? home-manager) {
    home-manager.sharedModules = [
      inputs.mac-app-util.homeManagerModules.default
    ];
  };
}
