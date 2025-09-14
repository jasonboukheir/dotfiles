{...}: {
  networking.nat = {
    enable = true;
    externalInterface = "enp5s0";
    internalInterfaces = ["wg0"];
  };
}
