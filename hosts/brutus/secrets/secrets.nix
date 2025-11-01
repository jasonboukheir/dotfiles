let
  jasonbk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBXQLA93+Bth7CcvuDjlu10Z03GmFg3CSLH4z+inadP";
in {
  "sunnycareboo-dot-com-zone-token.age".publicKeys = [jasonbk];
  "pocket-id-env.age".publicKeys = [jasonbk];
  "ddclient-token.age".publicKeys = [jasonbk];
  "firefly-iii-appkey.age".publicKeys = [jasonbk];
  "firefly-iii-data-importer-pat.age".publicKeys = [jasonbk];
  "liteLlmSecrets.age".publicKeys = [jasonbk];
  "mealie-env.age".publicKeys = [jasonbk];
  "nixarr-wgconf.age".publicKeys = [jasonbk];
  "opencloud-env.age".publicKeys = [jasonbk];
  "openWebuiSecrets.age".publicKeys = [jasonbk];
}
