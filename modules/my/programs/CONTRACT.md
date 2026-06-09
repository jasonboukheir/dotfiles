# `modules/my/programs/<tool>.nix` — the program-definition contract

Every file here is a **program definition**: a function `{ lib, pkgs }: { … }`
returning ONE shape. The framework (`../lib.nix`) turns each def into the
`my.<name>` (system) and `users.users.<n>.my.<name>` (per-user) option surfaces,
and the platform modules (`../nixos.nix`, `../nix-darwin.nix`,
`../home-manager.nix`) install the built package into the right environment.

**All programs are disabled by default.** A host opts in with `my.<name>.enable`
(system-wide) or `users.users.<n>.my.<name>.enable` (one user).

## The shape

```nix
{ lib, pkgs }: {
  # REQUIRED
  name = "jujutsu";                 # key under my.<name>
  build = { cfg, pkgs, lib, theme ? null, specialArgs ? {}, ... }:
    # Return the package to install. `cfg` is the resolved option set for this
    # scope (enable, package, + your `options`, + stylix if themeable) WITHOUT
    # finalPackage. Use pkgs.mkWrapped to bake config. Must be pure over
    # cfg/theme/specialArgs only — do NOT read the ambient module `config`.
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "jj";
      env.JJ_CONFIG = (pkgs.formats.toml {}).generate "jj-config.toml" cfg.settings;
    };

  # OPTIONAL
  defaultPackage = "jujutsu";       # pkgs attr (string or ["a" "b"]) -> adds a
                                    # `package` option (mkPackageOption). Omit
                                    # for tools that don't wrap one pkgs attr
                                    # (e.g. nvf builds via a specialArg).
  options = {                       # extra tool options, merged under my.<name>
    settings = lib.mkOption { type = (pkgs.formats.toml {}).type; default = {}; … };
  };
  themeable = true;                 # opt into stylix: adds my.<name>.stylix.enable
                                    # (default true) and passes a resolved `theme`
                                    # (or null) into build. Omit for un-themeable
                                    # tools (fd, rg, git, jj, gh).
  assertions = { cfg, specialArgs, lib }: [   # checked under mkIf enable
    { assertion = specialArgs.neovimConfiguration or null != null;
      message = "my.nvf.enable requires the neovimConfiguration specialArg."; }
  ];
}
```

## Universal options the framework adds (do NOT declare these yourself)

- `enable` — `mkEnableOption`, default **false**.
- `package` — only when `defaultPackage` is set.
- `finalPackage` — read-only; `= build { cfg = <resolved>; … }`. Tests read this.
- `stylix.enable` — only when `themeable = true`; default true.

## Cascade (system → per-user)

`users.users.<n>.my.<tool>.enable` defaults **false** (explicit opt-in). Every
*other* option deep-merges from the system `my.<tool>` value via per-leaf
`mkDefault`, so a user only writes the delta and wins on conflicts. You don't
implement this — the framework does. Just make `build` a pure function of `cfg`.

## stylix (themeable tools)

When `themeable`, `build` receives `theme` = `{ colors; polarity; fonts; opacity; }`
(base16 `colors` are `base00`..`base0F`, hex without `#`) when the integration is
on for this tool, else `null`. Bake it into the config and let the user's own
`settings` win (e.g. `lib.recursiveUpdate (themed theme) cfg.settings`). The
global toggle is `my.stylix.enable`; per-tool is `my.<tool>.stylix.enable`.

## Tests

Add `../tests/<name>-wrapper.nix` — a `{ pkgs, inputs ? null }` -> nixosTest that
asserts the **plumbing** (sentinel through `settings` -> read back via the wrapped
binary), never a real default. See `../tests/jujutsu-wrapper.nix`.

## Do NOT

- declare `enable`/`package`/`finalPackage`/`stylix.enable` (framework owns them);
- read the ambient module `config` inside `build` (only `cfg`/`theme`/`specialArgs`);
- edit `default.nix` — it auto-discovers every `*.nix` here; just drop your file;
- set system state (shells, login shell, services) — out of `my.*` scope.
