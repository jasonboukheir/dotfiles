{...}: {
  # The KVM in front of thebeast is unpowered, so switching inputs cuts
  # bus power to the downstream USB hub chain (GenesysLogic 05e3:0610 →
  # VIA Labs 2109:2822/0822 → keyboard+mouse). On power-up the VIA hub
  # re-enumeration intermittently hits "error -71 / device not accepting
  # address" and waits 10s for the xhci retry, which is what shows up as
  # a slow keyboard/mouse after hyprlock/hypridle. The legacy enumeration
  # scheme handles this hub firmware reliably.
  # TODO: drop once we move to a powered KVM/hub.
  # https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
  boot.kernelParams = ["usbcore.old_scheme_first=Y"];
}
