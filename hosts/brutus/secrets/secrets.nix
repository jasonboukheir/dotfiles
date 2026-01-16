let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPjx7uRpFx9S/K1rjIuoCFUuXnN+99oMtSah8KBjHBRq";
  backup = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC1d6WAsibDd8ewY0nhn52l4wMLOEkqwOoVdCAhm7kV";

  allKeys = [root backup];

  files = [
    "acme/env.age"
    "actual/env.age"
    "cloudflare/token.age"
    "davis/appSecret"
    "davis/clientSecret"
    "pocket-id/env.age"
    "litellm/env.age"
    "mealie/env.age"
    "nixarr-wgconf.age"
    "opencloud-env.age"
    "open-webui/env.age"
    "photos/clientId.age"
    "photos/clientSecret.age"
    "restic/env.age"
    "restic/repo.age"
    "restic/password.age"
    "searx/env.age"
    "headscale/clientSecret.age"
    "tailscale/authkey.age"
    "power/ups/user/pw.age"
  ];
in
  # Generate the configuration for each file
  builtins.listToAttrs (map (file: {
      name = file;
      value = {
        armor = true;
        publicKeys = allKeys;
      };
    })
    files)
