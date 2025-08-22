{...}: {
  sops.defaultSopsFile = ./.encrypted_secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/var/lib/sops-nix/keys.txt";
  sops.secrets = {
    "traefik/env" = {
      owner = "nginx";
      group = "nginx";
      mode = "0400";
    };
    "pocket-id/env" = {
      owner = "pocket-id";
      group = "pocket-id";
      mode = "0400";
    };
  };
}
