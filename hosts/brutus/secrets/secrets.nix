let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPjx7uRpFx9S/K1rjIuoCFUuXnN+99oMtSah8KBjHBRq";
in {
  "sunnycareboo-dot-com-zone-token.age" = {
    armor = true;
    publicKeys = [root];
  };
  "pocket-id-env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "firefly-iii-appkey.age" = {
    armor = true;
    publicKeys = [root];
  };
  "firefly-iii-data-importer-pat.age" = {
    armor = true;
    publicKeys = [root];
  };
  "liteLlmSecrets.age" = {
    armor = true;
    publicKeys = [root];
  };
  "mealie-env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "nixarr-wgconf.age" = {
    armor = true;
    publicKeys = [root];
  };
  "opencloud-env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "openWebui-env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "acme-env.age" = {
    armor = true;
    publicKeys = [root];
  };
}
