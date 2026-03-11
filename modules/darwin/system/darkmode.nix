{
  config,
  lib,
  ...
}: {
  system.defaults.NSGlobalDomain = {
    AppleInterfaceStyle =
      if config.stylix.polarity == "dark"
      then "Dark"
      else null;
    AppleInterfaceStyleSwitchesAutomatically = false;
  };
}
