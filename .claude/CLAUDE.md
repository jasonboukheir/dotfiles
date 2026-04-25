Nix flakes project.

- use the flakes CLI (`nix run`/`shell`/`build`), not legacy `nix-shell`/`nix-channel`.
- prefer existing module options over manual config (e.g. `services.nginx.*` rather than writing to `/etc`). Expose new tunable values as options, not `let`-bound consts.
- TODO comment with upstream link for temporary workarounds.
