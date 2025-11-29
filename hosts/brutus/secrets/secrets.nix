let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPjx7uRpFx9S/K1rjIuoCFUuXnN+99oMtSah8KBjHBRq";
in {
  "acme/env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "actual/env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "cloudflare/token.age" = {
    armor = true;
    publicKeys = [root];
  };
  "pocket-id-env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "litellm/env.age" = {
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
  "open-webui/env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "photos/clientId.age" = {
    armor = true;
    publicKeys = [root];
  };
  "photos/clientSecret.age" = {
    armor = true;
    publicKeys = [root];
  };
  "restic/env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "restic/repo.age" = {
    armor = true;
    publicKeys = [root];
  };
  "restic/password.age" = {
    armor = true;
    publicKeys = [root];
  };
  "searx/env.age" = {
    armor = true;
    publicKeys = [root];
  };
  "headscale/clientSecret.age" = {
    armor = true;
    publicKeys = [root];
  };
}
