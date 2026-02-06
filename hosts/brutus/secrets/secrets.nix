let
  root = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPjx7uRpFx9S/K1rjIuoCFUuXnN+99oMtSah8KBjHBRq";
  backup = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDC1d6WAsibDd8ewY0nhn52l4wMLOEkqwOoVdCAhm7kV";

  allKeys = [root backup];

  files = [
    "acme/env.age"
    "cloudflare/token.age"
    "litellm/env.age"
    "lldap/jwt_secret.age"
    "lldap/users/admin/pw.age"
    "mealie/openaiApiKey.age"
    "nixarr/wgconf.age"
    "open-webui/openaiApiKey.age"
    "open-webui/webuiSecretKey.age"
    "pocket-id/encryptionKey.age"
    "pocket-id/staticApiKey.age"
    "power/ups/user/pw.age"
    "restic/env.age"
    "restic/password.age"
    "restic/repo.age"
    "searx/env.age"
    "step-ca/intermediatePassword.age"
    "tailscale/authkey.age"
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
