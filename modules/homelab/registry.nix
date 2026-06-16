{lib, ...}: let
  # Shared service catalog: which homelab services exist and whether each
  # is external. `isExternal` is the only per-service fact here because it
  # is the one cross-host fact — it decides each service's computed
  # `domain` (`<name>.<domain>` vs `<name>.internal.<domain>` in
  # modules/homelab/services.nix), so every host imports this to resolve
  # service domains without running anything. Per-host hosting wiring
  # (proxyPass, mtls, wildcard) stays with the implementations.
  #
  # The matching implementations (proxyPass, mtls, the actual `services.*`
  # config) live under ./services and are imported only by the host that
  # actually serves them, alongside the backing flake inputs. Enabling a
  # service is a per-host choice (e.g. hosts/brutus/services/homelab.nix),
  # not part of the catalog.
  #
  # `registered = true` is stamped on every catalog entry so services.nix
  # can assert that no enabled service is missing from this list — without
  # the marker a forgotten entry would silently default to internal.
  external = [
    "ai"
    "audiobookshelf"
    "budget"
    "call"
    "chat"
    "cloud"
    "code"
    "git"
    "gonic"
    "headscale"
    "home"
    "id"
    "jellyfin"
    "matrix-auth"
    "matrix-rtc"
    "meals"
    "memos"
    "ntfy"
    "photos"
    "radicale"
    "search"
    "seer"
    "synapse"
  ];

  internal = [
    "bazarr"
    "blocky"
    "certs"
    "lidarr"
    "lldap"
    "llm"
    "prowlarr"
    "radarr"
    "sonarr"
    "transmission"
  ];

  register = isExternal:
    lib.genAttrs (
      if isExternal
      then external
      else internal
    ) (_: {
      registered = true;
      inherit isExternal;
    });
in {
  homelab.services = register true // register false;
}
