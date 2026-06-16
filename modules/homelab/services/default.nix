{inputs, ...}: {
  imports = [
    # These services are built around separate flake inputs, so pull each
    # input's NixOS module in here — alongside the service modules that
    # configure them — and the hosting host gets the backing options just
    # by importing this services layer. The host still supplies its own
    # hardware/media/secret config (e.g. nixarr.mediaDir, the Intel-XPU
    # device, agenix secrets) in hosts/<host>.
    inputs.ezmtls.nixosModules.default
    inputs.nixarr.nixosModules.default
    inputs.vllm-xpu-nix.nixosModules.default

    ./actual
    ./coder
    ./element-call
    ./element-web
    ./ezmtls
    ./forgejo
    ./gonic.nix
    ./headscale
    ./home-assistant
    ./immich
    ./litellm.nix
    ./lldap.nix
    ./matrix-auth
    ./matrix-bridges
    ./matrix-rtc
    ./matrix-synapse
    ./mealie
    ./memos.nix
    ./nixarr
    ./ntfy.nix
    ./open-webui
    ./opencloud
    ./pocket-id.nix
    ./radicale.nix
    ./searx.nix
    ./seerr.nix
  ];
}
