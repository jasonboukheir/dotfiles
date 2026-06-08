- clean code conventions for comments
  - comments generally are a code smell
  - comments useful for short TODO, or detailed quirk that can't be looked up.
  - prefer assertions or named variables to comments
- use the flakes CLI (`nix run`/`shell`/`build`), not legacy
  `nix-shell`/`nix-channel`.
- prefer existing module options over manual config (e.g. `services.nginx.*`
  rather than writing to `/etc`).
- Expose new tunable values as options, preferred over `let` variables.
- TODO comment with upstream link for temporary workarounds.
- where possible write nix vm tests to test assumptions
- do NOT use tests to validate the system config is set to a given value
