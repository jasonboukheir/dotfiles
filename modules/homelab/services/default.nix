{inputs, ...}: {
  imports = [
    # ezmtls is a separate flake input that the homelab mTLS framework is
    # built around, so pull its NixOS module in here — alongside the
    # service module that configures it — and the hosting host gets both
    # just by importing this services layer.
    inputs.ezmtls.nixosModules.default

    ./actual
    ./coder
    ./element-call
    ./element-web
    ./ezmtls
    ./gonic.nix
    ./headscale
    ./home-assistant
    ./immich
    ./lldap.nix
    ./matrix-auth
    ./matrix-bridges
    ./matrix-rtc
    ./matrix-synapse
    ./mealie
    ./memos.nix
    ./ntfy.nix
    ./open-webui
    ./opencloud
    ./pocket-id.nix
    ./radicale.nix
    ./searx.nix
    ./seerr.nix
  ];
}
