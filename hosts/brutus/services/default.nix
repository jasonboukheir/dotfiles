{...}: {
  imports = [
    ./opencloud
    ./actual.nix
    ./blocky.nix
    ./litellm.nix
    ./mealie.nix
    ./nextcloud.nix
    ./nginx.nix
    ./open-webui.nix
    ./openssh.nix
    ./pocket-id.nix
    ./postgresql.nix
  ];
}
