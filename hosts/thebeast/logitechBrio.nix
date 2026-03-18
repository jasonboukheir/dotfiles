{
  config,
  lib,
  ...
}: let
  vendorId = "046d";
  productId = "085e";
  disableLpmQuirk = "l";
in {
  options.logitech.brio.enableUsbLpm = lib.mkEnableOption "USB Link Power Management for the Logitech Brio 4K (046d:085e)";

  config = lib.mkIf (!config.logitech.brio.enableUsbLpm) {
    boot.kernelParams = [
      "usbcore.quirks=${vendorId}:${productId}:${disableLpmQuirk}"
    ];
  };
}
