# Brutus Impermanence Checklist Plan

## Context

Setting up impermanence on brutus means the ext4 root (`/`) will be wiped on each reboot. The ZFS pools (`/ssd_pool`, `/ext_pool`) are already persistent via LUKS encryption. The goal of this plan is a thorough checklist of all state paths to audit — not implementation steps.

**Key architecture facts:**
- `/` is ext4 (target for impermanence wipe)
- `/ssd_pool` and `/ext_pool` are ZFS (LUKS-encrypted, persistent)
- LUKS key lives at `/var/lib/secrets/data.key` — **this must be solved first or the ZFS pools won't unlock**
- `/var/lib/nixarr` is already bind-mounted from `/ssd_pool/var/lib/nixarr` → all nixarr service state is already persistent

---

## Prerequisites — Do These First

### 1. Full Disk Encryption on Root

**Do this before impermanence.** Without FDE, `/var/lib/secrets/data.key` lives on an unencrypted ext4 root. If impermanence wipes `/var/lib`, the ZFS pools can't unlock on next boot.

**Target boot sequence:**
1. initrd boots → SSH available on port 2222 (already configured in `networking/initrd-ssh.nix`)
2. SSH in remotely → provide LUKS passphrase → root unlocks
3. Root mounts → `/var/lib/secrets/data.key` is accessible
4. ZFS pools (`ssd_pool`, `ext_pool`) decrypt and mount
5. Impermanence bind mounts run → services start

**Verify before moving on:**
- [ ] Root partition is LUKS-encrypted
- [ ] initrd SSH (port 2222) works and you can actually unlock the disk remotely
- [ ] ZFS pools mount correctly after remote unlock
- [ ] Normal boot proceeds after unlock

---

## Checklist

### ⚠️ Pre-condition: Boot-time Encryption Key (solved by FDE above)

With FDE in place, `/var/lib/secrets/data.key` lives on the encrypted root — it's available after remote LUKS unlock and before ZFS mounts. No special handling needed beyond the FDE setup.

---

### System State (on ephemeral root)

- [ ] **`/etc/machine-id`** — systemd journal continuity; must be fixed or bind-mounted
- [ ] **`/etc/ssh/ssh_host_*_key`** — SSH host keys; changing these will cause "host key changed" warnings for all clients
- [ ] **`/etc/secrets/initrd/ssh_host_ed25519_key`** — initrd SSH host key (for remote unlock at boot, port 2222)

---

### Critical Service State (must persist via bind mount to ZFS)

- [ ] **`/var/lib/postgresql`** — backs immich, mealie, open-webui, litellm databases; total loss if wiped
- [ ] **`/var/lib/tailscale`** — VPN node keys/state; requires re-auth to headscale if lost
- [ ] **`/var/lib/headscale`** — coordinator DB (node registrations, routes, ACLs); all clients need re-auth if lost
- [ ] **`/var/lib/lldap`** — LDAP directory (all users/groups: jasonbk, izmabk, radicale, service accounts)
- [ ] **`/var/lib/pocket-id`** — OIDC client registrations (headscale, ezmtls, opencloud, etc.); all SSO breaks if lost
- [ ] **`/var/lib/ezmtls`** — mTLS CA private key and certificates; must regenerate entire PKI if lost
- [ ] **`/var/lib/acme`** — Let's Encrypt certs; won't break immediately but will fail on renewal if path disappears

---

### High Priority Service State

- [ ] **`/var/lib/radicale/collections`** — calendar and contact data (CalDAV/CardDAV)
- [ ] **`/var/lib/mealie`** — recipe database and images (PostgreSQL handles DB but Mealie may store uploads here)
- [ ] **`/var/lib/actual`** — budget databases and transaction history
- [ ] **`/var/lib/open-webui`** — AI conversation history (PostgreSQL handles DB; verify if any local file storage)
- [ ] **`/var/lib/memos`** — notes/memos (check if SQLite or PostgreSQL; if SQLite it's critical)

---

### Nixarr (Already on ZFS — Verify Only)

nixarr's `stateDir = /var/lib/nixarr/.state/nixarr` is bind-mounted from `/ssd_pool/var/lib/nixarr`, so these are **already persistent**. Just verify the bind mount is set up before services start:

- [ ] **Sonarr** — `/var/lib/nixarr/.state/nixarr/sonarr`
- [ ] **Radarr** — `/var/lib/nixarr/.state/nixarr/radarr`
- [ ] **Lidarr** — `/var/lib/nixarr/.state/nixarr/lidarr`
- [ ] **Readarr** — `/var/lib/nixarr/.state/nixarr/readarr`
- [ ] **Readarr-audiobook** — `/var/lib/nixarr/.state/nixarr/readarr-audiobook`
- [ ] **Prowlarr** — `/var/lib/nixarr/.state/nixarr/prowlarr`
- [ ] **Bazarr** — `/var/lib/nixarr/.state/nixarr/bazarr`
- [ ] **Jellyfin** — `/var/lib/nixarr/.state/nixarr/jellyfin`
- [ ] **Jellyseerr** — `/var/lib/nixarr/.state/nixarr/jellyseerr`
- [ ] **Audiobookshelf** — `/var/lib/nixarr/.state/nixarr/audiobookshelf/{config,metadata}`
- [ ] **Transmission** — `/var/lib/nixarr/.state/nixarr/transmission` + port-forwarding state
- [ ] **`/var/cache/jellyfin`** — Jellyfin cache is NOT under nixarr's bind mount; check if this is on ext4 (it's regenerable but slow to rebuild — thumbnails, metadata)

---

### Medium Priority / Probably Persist

- [ ] **`/var/lib/immich`** — verify if bind-mounted from `/ssd_pool/var/lib/immich`; if not, add it
- [ ] **`/var/lib/opencloud`** — verify if bind-mounted from `/ssd_pool/var/lib/opencloud`; if not, add it
- [ ] **`/var/lib/libation`** — audiobook downloads and library metadata

---

### Probably Skip (Regenerates on Boot)

- `/var/lib/blocky` — DNS cache (auto-rebuilds from blocklists)
- `/var/cache/ddclient` — last-sent IP (just causes one extra Cloudflare update)
- `/var/lib/nut` — UPS status history
- `/var/lib/redis` — Searx cache
- `/var/lib/systemd/timesync` — NTP drift data

---

### User Home State (`/home/jasonbk`)

- [ ] **`/home/jasonbk/.ssh`** — SSH private keys and authorized_keys
- [ ] **`/home/jasonbk/.config/nix`** — git repo, already managed (just needs the directory to exist)
- [ ] **`/home/jasonbk/.local/share`** — fish history, direnv cache, other user data
- [ ] Audit what home-manager manages declaratively vs what accumulates as mutable state

---

### Gaps to Investigate

1. **`/var/lib/secrets/data.key` boot ordering** — the ZFS pools must mount before any service bind mounts can work; this is the trickiest part of impermanence with LUKS-encrypted ZFS
2. **Headscale backend** — config doesn't specify SQLite vs PostgreSQL; if it's using its own SQLite (default), `/var/lib/headscale` is the target; if using PostgreSQL, it's covered already
3. **ezmtls state path** — module uses `cfg.ensureCAs.mtls.certFile`; need to confirm actual path on disk is under `/var/lib/ezmtls`
4. **LiteLLM container** — uses Podman OCI container; check if Podman stores any container state in `/var/lib/containers` that needs persisting
5. **Virtualization** — check `virtualization.nix` for any VM disk images or libvirt state
6. **Agenix secrets** — populated at boot from nix store derivations, don't need persistence themselves
