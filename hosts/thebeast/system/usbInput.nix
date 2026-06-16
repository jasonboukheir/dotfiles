{
  config,
  lib,
  ...
}: let
  cfg = config.thebeast.usbInput;

  # The wired keyboard sits at the bottom of a hub chain (lsusb -t):
  #   Plain60 4705:0160 -> VIA 2109:2822 -> VIA 2109:2822 -> Genesys 05e3:0610
  # with the KVM (09ea:0130) on a sibling port. Pinning these hubs is what
  # makes a re-plug behind them re-enumerate without resuming an autosuspended
  # port the slow way (toggling the KVM).
  keyboardChainHubs = [
    {
      vendor = "2109";
      product = "2822";
    } # VIA Labs dock hubs (cascaded x2)
    {
      vendor = "05e3";
      product = "0610";
    } # Genesys upstream hub
  ];

  awakeRule = h: ''ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${h.vendor}", ATTR{idProduct}=="${h.product}", TEST=="power/control", ATTR{power/control}="on"'';
in {
  options.thebeast.usbInput = {
    keepHubsAwake = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pin power/control=on for the USB hubs the wired keyboard sits
        behind (VIA Labs 2109:2822, Genesys 05e3:0610). With the kernel's
        default 2s autosuspend, an autosuspended hub port misses the
        connect-change interrupt when a device is re-plugged behind it, so
        the keyboard never re-enumerates until the KVM is switched (which
        forces the upstream hub to resume and re-drive port power).
        Targeted at these hubs so autosuspend stays on everywhere else.
      '';
    };

    disableHubLpm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Escalation for keepHubsAwake: disable USB2 Link Power Management
        for the same hubs via the usbcore.quirks `k` flag. VIA 2109:2822
        hubs are known to mishandle LPM, which can also drop a re-plug
        edge. Off by default because it needs a reboot; try keepHubsAwake
        first.
      '';
    };

    quirks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["046d:085e:k"];
      description = ''
        usbcore.quirks entries, each "vid:pid:flags". Merged into the
        single usbcore.quirks= kernel parameter the kernel honours — the
        kernel keeps only the last such param it sees, so features that
        need a USB quirk must append here rather than setting
        boot.kernelParams directly.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.keepHubsAwake {
      services.udev.extraRules = lib.concatMapStringsSep "\n" awakeRule keyboardChainHubs + "\n";
    })

    (lib.mkIf cfg.disableHubLpm {
      thebeast.usbInput.quirks = map (h: "${h.vendor}:${h.product}:k") keyboardChainHubs;
    })

    (lib.mkIf (cfg.quirks != []) {
      boot.kernelParams = ["usbcore.quirks=${lib.concatStringsSep "," cfg.quirks}"];
    })
  ];
}
