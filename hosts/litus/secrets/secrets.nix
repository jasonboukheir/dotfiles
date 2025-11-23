let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPjx7uRpFx9S/K1rjIuoCFUuXnN+99oMtSah8KBjHBRq";
in {
  "acme/env.age" = {
    armor = true;
    publicKeys = [root];
  };
}
