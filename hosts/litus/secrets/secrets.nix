let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA3QeouGnA3F+Rry67iZRWvd+CpOp+NcEnt2VZ03PVGH";
in {
  "acme/env.age" = {
    armor = true;
    publicKeys = [root];
  };
}
