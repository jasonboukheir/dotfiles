{
  description = "NixOS-only inputs partition.";

  inputs = {
    nixos.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixos";
    };

    home-manager-nixos-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    stylix-nixos-unstable = {
      url = "github:nix-community/stylix/master";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    nvf-nixos-unstable = {
      url = "github:notashelf/nvf/main";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS/development";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    # TODO: do NOT add inputs.nixpkgs.follows here. Upstream README warns that
    # overriding nixpkgs causes mismatch between cachy patches and kernel version.
    # https://github.com/xddxdd/nix-cachyos-kernel#how-to-use-kernels
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # TODO: nixarr's transitive flake graph (vpnconfinement, website-builder) is
    # historically brittle under follows overrides. Leave on its own pin until a
    # nixarr release documents follows compatibility.
    # https://github.com/rasmus-kirk/nixarr
    #
    # Pinned: rev 7eae4e1 (Apr 29 2026) imports ./shelfmark, which sets
    # services.shelfmark — an option not yet backported to nixos-25.11. Lift
    # the pin once `nixos/modules/services/misc/shelfmark.nix` exists on the
    # 25.11 branch.
    nixarr.url = "github:rasmus-kirk/nixarr/077bb8a83d6d07b25e098638db50d0ac80456174";

    ezmtls = {
      url = "git+https://codeberg.org/jasonboukheir/ezmtls.git?ref=main";
      inputs.nixpkgs.follows = "nixos";
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixos";
    };

    # Native vLLM-XPU build (torch+xpu, triton-xpu, vllm-xpu-kernels, vllm)
    # plus a NixOS module exposing services.vllm-xpu.instances.<name>.
    # Tracks nixos-unstable because the closure depends on
    # pkgs.intel-oneapi.base which only landed there.
    vllm-xpu-nix = {
      url = "github:jasonboukheir/vllm-xpu-nix";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    helium-flake = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    # Upstream CSS for the Catppuccin Steam Deck theme, consumed verbatim
    # by hosts/thebeast/session/steam-theme.nix. We don't take their
    # palette — only the selector library in `src/shared.css` — and
    # alias their `--ctp-*` vars to the active Stylix base16 scheme.
    # Refresh with `nix flake update catppuccin-steam-deck` whenever a
    # Steam client beta rotates webpack hashes; upstream's CSSLoader
    # Mappings dependency keeps their selectors in sync with the latest
    # Steam build.
    catppuccin-steam-deck = {
      url = "github:catppuccin/steam-deck";
      flake = false;
    };
  };

  outputs = _: {};
}
