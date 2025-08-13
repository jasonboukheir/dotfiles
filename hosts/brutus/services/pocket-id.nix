{ ... }: {
  services.pocket-id = {
    enable = true;
    environmentFile = "/var/lib/secrets/pocket-id.env";
  };
}
