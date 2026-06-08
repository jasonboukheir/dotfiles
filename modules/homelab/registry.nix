{...}: {
  # Shared service catalog: which homelab services exist and whether each
  # is external. `isExternal` is the only field here because it is the one
  # cross-host fact — it decides each service's computed `domain`
  # (`<name>.<domain>` vs `<name>.internal.<domain>` in
  # modules/homelab/services.nix), so every host imports this to resolve
  # service domains without running anything. Per-host hosting wiring
  # (proxyPass, mtls, wildcard) stays with the implementations.
  #
  # The matching implementations (proxyPass, mtls, the actual `services.*`
  # config) live under ./services and are imported only by the host that
  # actually serves them, alongside the backing flake inputs. Enabling a
  # service is a per-host choice (e.g. hosts/brutus/services/homelab.nix),
  # not part of the catalog.
  homelab.services = {
    ai.isExternal = true;
    budget.isExternal = true;
    call.isExternal = true;
    chat.isExternal = true;
    cloud.isExternal = true;
    code.isExternal = true;
    gonic.isExternal = true;
    headscale.isExternal = true;
    home.isExternal = true;
    id.isExternal = true;
    matrix-auth.isExternal = true;
    matrix-rtc.isExternal = true;
    meals.isExternal = true;
    memos.isExternal = true;
    ntfy.isExternal = true;
    photos.isExternal = true;
    radicale.isExternal = true;
    search.isExternal = true;
    seer.isExternal = true;
    synapse.isExternal = true;

    certs.isExternal = false;
    lldap.isExternal = false;
  };
}
