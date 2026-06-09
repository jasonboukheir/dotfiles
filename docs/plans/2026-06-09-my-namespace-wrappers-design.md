# Design: `my.*` namespace for wrapped programs

Migrating off home-manager (epic [#36]) introduced per-user hand-rolled wrappers
under `programs.<tool>` / `users.users.<name>.programs.<tool>`. This design
reorganizes that into a dedicated `my.*` namespace with explicit
system-vs-per-user semantics, a single program-definition contract, and three
platform consumers, all under `modules/my/`.

## Goals

- `my.<tool>.enable` installs a configured (wrapped) package **system-wide** (all
  users).
- `users.users.<name>.my.<tool>.enable` installs it **for one user**, whose
  config **cascades from** and **deep-merges over** the system config, and whose
  wrapper **shadows** the system one in that user's PATH.
- One reorganized tree, `modules/my/`, with three platform modules
  (`nixos.nix`, `nix-darwin.nix`, `home-manager.nix`) consuming one set of
  program definitions.
- `my.*` is **only** "configure a package and install it in the right
  environment." It never sets system state (shell registration, login shell,
  services). Those stay on normal NixOS/darwin options, out of scope here.

## Why `my.*`

Short, collision-free with upstream `programs.*` (which carries hundreds of
NixOS/HM options). The current scheme overloads `programs.*`, which both risks
collisions and conflates "native upstream module" with "our wrapper." A private
prefix cleanly separates our surface.

## Directory layout

```
modules/my/
  lib.nix              # framework: builds the option tree + cascade + install
  programs/
    default.nix        # collects all program defs into an attrset
    git.nix  jujutsu.nix  gh.nix  starship.nix  ghostty.nix
    fish.nix  direnv.nix  nvf/  fd.nix  rg.nix  nushell/
  system-scope.nix     # shared system+per-user core for nixos & nix-darwin
  nixos.nix            # thin: imports system-scope, installs into NixOS surfaces
  nix-darwin.nix       # thin: imports system-scope, installs into darwin surfaces
  home-manager.nix     # standalone-HM: my.<tool> (single user) -> home.packages
  values/
    jasonbk.nix        # jasonbk's per-user values (users.users.jasonbk.my.*)
  tests/
    default.nix        # auto-registers every *.nix as a flake check
    <tool>-wrapper.nix # plumbing assertions per tool
```

`pkgs.mkWrapped` (`modules/nixpkgs/overlays/mkWrapped.nix`) stays as-is — the
build primitive every package program uses.

## The program-definition contract

Every `modules/my/programs/<tool>.nix` is a function returning **one shape**:

```nix
{ lib, pkgs }: {
  name = "jujutsu";              # key under my.<name> / users.users.<n>.my.<name>
  defaultPackage = "jujutsu";    # attr name into pkgs for mkPackageOption
  options = {                    # tool-specific options ONLY (freeform/scalars)
    settings = lib.mkOption {
      type = (pkgs.formats.toml {}).type;
      default = {};
      description = "Baked into this jj wrapper via JJ_CONFIG.";
    };
  };
  build = { cfg, specialArgs }: pkgs.mkWrapped {   # resolved cfg -> installed pkg
    pkg = cfg.package;
    name = "jj";
    env.JJ_CONFIG = (pkgs.formats.toml {}).generate "jj-config.toml" cfg.settings;
  };
}
```

`lib.nix` injects the **universal** options into every tool, so tool files never
declare them:

- `enable` — `mkEnableOption`.
- `package` — `mkPackageOption pkgs defaultPackage {}`.
- `finalPackage` — read-only, `= build { cfg = <this scope's resolved cfg>; inherit specialArgs; }`.

There is no `native`/`system`/`user`/`userUnsupported` distinction: tools that
used to rely on system-level shell integration (fish, direnv) bake that
integration into their wrapper instead (see "fish & direnv" below).

`build` receives `specialArgs` so nvf can read `neovimConfiguration` (see "nvf").

## Option scopes & cascade

`lib.nix` defines **one** shared submodule type from the program defs (the
`my.<tool>` surface: `enable`/`package`/`finalPackage` + each tool's options) and
uses it for **both** scopes — no two parallel option trees to keep in sync. It is
built with `lib.types.submoduleWith { specialArgs = { … }; modules = [ … ]; }` so
the submodule receives `neovimConfiguration` (plain `submodule`s do **not**
inherit the parent `nixosSystem`/`darwinSystem` `specialArgs` — verified in
review, C2).

**System scope** — declared by every platform module:

```nix
options.my = mkOption { type = myProgramsSubmodule; default = {}; };
# -> config.my.<tool>.{enable,package,finalPackage,...}
```

**Per-user scope** — declared by `nixos.nix`/`nix-darwin.nix` only, by
module-merging the same submodule type onto `users.users.<name>`:

```nix
options.users.users = mkOption {
  type = attrsOf (submodule { options.my = mkOption { type = myProgramsSubmodule; default = {}; }; });
};
```

**Cascade rules** — implemented in the platform module (which *does* receive
specialArgs and the top-level `config`) by pushing the system config into each
user's `my` as **per-leaf** `mkDefault` definitions:

- `enable` defaults to **`false`** (explicit per-user opt-in). A system-enabled
  tool therefore does **not** redundantly fan a per-user copy into every user
  profile; users opt in only to override.
- For every **other** option, the cascade recurses the system value and wraps
  **each leaf** in `lib.mkDefault` (a `mapAttrsRecursive`-style walk), then sets
  that as a config definition on `users.users.<n>.my.<tool>`:

  ```nix
  # per user, per tool, in the platform module:
  users.users.<n>.my.<tool> = recursiveMkDefault (removeAttrs config.my.<tool> ["enable" "finalPackage"]);
  ```

  This is the **load-bearing mechanic** and the one the review proved must be
  per-leaf: a whole-attrset `mkDefault` is a single low-priority definition that
  the module system drops entirely once the user sets the option, silently
  losing all system keys. Per-leaf `mkDefault` instead **deep-merges** nested
  keys with the user's explicit settings while letting the user **win on
  scalars** (verified empirically). List leaves are replaced, not concatenated
  (intended). This is exactly the pattern `modules/stylix/users/ghostty.nix:49`
  (`lib.mapAttrs (_: lib.mkDefault) themed`) already uses for its target.

Example:

```nix
my.git.settings.init.defaultBranch = "main";                # system
users.users.alice.my.git = {                                # alice opts in
  enable = true;
  settings.user.email = "a@x";                              # merges over system
};
# alice's wrapper: { init.defaultBranch="main"; user.email="a@x"; }
# bob: no per-user entry -> uses the system wrapper unchanged
```

## Installation surfaces & PATH precedence

| Module | `my.<tool>.enable` | `users.users.<n>.my.<tool>.enable` |
|---|---|---|
| `nixos.nix` | `environment.systemPackages += finalPackage` | `users.users.<n>.packages += finalPackage` |
| `nix-darwin.nix` | `environment.systemPackages += finalPackage` | `users.users.<n>.packages += finalPackage` |
| `home-manager.nix` | `home.packages += finalPackage` | n/a (standalone = one user) |

The system+per-user logic is identical between NixOS and nix-darwin, so both
live in `modules/my/system-scope.nix`; `nixos.nix` and `nix-darwin.nix` are thin
imports (kept as separate files per the requested layout, and to host any future
platform-specific divergence).

**Precedence requirement:** a per-user wrapper must shadow the system one. On
NixOS, `users.users.<n>.packages` populate `/etc/profiles/per-user/<n>`, which
precedes `/run/current-system/sw` in the session `PATH` (via `NIX_PROFILES`
ordering) — so the per-user wrapper wins. This is the load-bearing assumption of
the cascade and is asserted by a dedicated VM test (`override-precedence`).

## nvf via `neovimConfiguration` specialArg

nvf bakes its entire config into the neovim derivation and needs a
channel-matched builder (`nvf-darwin` / `nvf-nixos` / `nvf-nixos-unstable`).

- The `neovimConfiguration` **module option is removed**. The nvf program def's
  `build` reads `specialArgs.neovimConfiguration` — which reaches the submodule
  because the `my` submodule type is built with `submoduleWith { specialArgs }`
  (C2 fix). The **assertion** for a missing specialArg fires from the top-level
  platform module (which owns specialArgs), guarded so it only triggers when nvf
  is enabled (no eval error when disabled — S5):

  ```nix
  assertions = [{
    assertion = !config.my.nvf.enable || (specialArgs ? neovimConfiguration);
    message = ''my.nvf.enable requires the `neovimConfiguration` specialArg.
      Set it where the config is built:
        specialArgs.neovimConfiguration = inputs.nvf-<channel>.lib.neovimConfiguration;'';
  }];
  ```

- The specialArg is set per-configuration in each partition's `default.nix`
  (today it's a `programs.nvf.neovimConfiguration` **module option** set in
  **host** files — `hosts/{thebeast,brutus,litus}/nvf.nix`,
  `modules/darwin/programs/nvf.nix` — and the nvf inputs live in per-partition
  `flake.nix`, not root). The move edits each `nixosSystem`/`mkHost` call:
  - `modules/flake/darwin/default.nix` → `inputs.nvf-darwin...` (darwin uses one
    shared specialArgs for **both** macs — fine, both use `nvf-darwin`).
  - `modules/flake/nixos/default.nix` → per-host specialArgs:
    `inputs.nvf-nixos...` (stable hosts), `inputs.nvf-nixos-unstable...`
    (unstable host `thebeast`). The stable/unstable split must be preserved.
  - `modules/flake/home/default.nix` → `inputs.nvf-nixos...`
- `my.nvf` keeps its `meta` (fb meta.nvim plugin) and `settings` (deferredModule)
  options. `finalPackage` is the built wrapped neovim, installed via the standard
  surfaces (default system scope; per-user override allowed).

## fish & direnv (no longer native exceptions)

Both become ordinary package programs with baked config — there is **no system
fish module**. The review (C3) confirmed this is feasible but is more than "bake
`interactiveShellInit`": the wrapper must reproduce the vendor-path machinery the
system module used to provide. Concretely the wrapped fish bakes:

- a config dir it points at (`XDG_CONFIG_HOME` / `$__fish_config_dir`) holding
  `config.fish` + `conf.d/*` carrying the init hooks HM used to emit (starship
  init, `direnv hook fish`, carapace completer, vivid `LS_COLORS`), and
- `XDG_DATA_DIRS` (and/or `fish_complete_path` / `fish_function_path`) extended
  to the plugin packages' `share/fish/vendor_{completions,functions,conf}.d` so
  `plugin-git`, carapace completions, etc. resolve **per-user** without a system
  profile contributing them.

`direnv` (`my.direnv`) wraps direnv with a baked `direnvrc` (sourcing nix-direnv)
/ `direnv.toml`. The `direnv hook fish` line lives in the fish wrapper's baked
`conf.d`; direnv must be installed in the same environment.

**Deferred (genuinely system config, out of `my.*`):** making the wrapped fish
the user's actual **login/interactive shell** — `/etc/shells` registration and
`users.users.<n>.shell` — is NOT set by `my.*`. So `my.fish` yields a fully
configured fish on `PATH` (correct prompt/completions/hooks when invoked), but it
becomes the *default* shell only once that separate system wiring lands (a later
refactor). This is the accepted trade-off (chosen explicitly).

Standalone-HM hosts (devserver, fedora) still get login-shell wiring via HM until
their cutover (#39); `my.fish`/`my.direnv` give them the configured package via
`home.packages`.

## fd / rg

Trivial package programs: no wrapper, `build = { cfg, ... }: cfg.package`. They
exist to bring fd/rg under the uniform `my.<tool>` enable/install surface.

**Behavior change to call out (S3):** today `modules/programs/fd.nix` /`rg.nix`
do `environment.systemPackages = [pkgs.fd]` unconditionally. Moving to
`my.fd.enable` makes them **opt-in/enable-gated**, so the migration must set
`my.fd.enable`/`my.rg.enable` (system scope) on every host that has them today,
or they silently disappear.

## Stylix integration (automatic, per-package target)

Rather than hand-writing one target per app (`modules/stylix/users/ghostty.nix`),
theming is a **framework feature**: a single per-package target applied to every
`my.<tool>`, auto-enabled when stylix is defined — mirroring how upstream stylix
auto-enables its targets.

- A program def *optionally* declares a **theme mapper**:

  ```nix
  # in a program def, e.g. ghostty
  stylix = { theme }: {            # theme = resolved base16 colors/fonts/polarity/opacity
    background = "#${theme.base00}";
    foreground = "#${theme.base05}";
    palette = [ "0=#${theme.base00}" ... ];
  };                                # -> a `settings` fragment for this tool
  ```

  Tools with no `stylix` attr are simply not themed.

- The framework wires one target per package: when the integration is on for a
  tool, it merges `stylix { theme }` into that tool's `settings` via **per-leaf
  `lib.mkDefault`** (so the user's explicit `settings` still win — same mechanic
  as the cascade, and what `ghostty.nix:49` does today).

- `theme` is the resolved stylix theme, sourced from the system stylix config
  (`config.lib.stylix.colors`, `config.stylix.{polarity,fonts,opacity}`) with the
  existing per-user override surface (`modules/stylix/users/options.nix`, kept).
  Guarded with `or` fallbacks so importing onto a host with no system stylix is a
  no-op, not an eval error.

- **Toggles:**
  - Global: `my.stylix.enable` — the whole `my.* ↔ stylix` integration. Defaults
    to whether stylix is defined/enabled on the host.
  - Per-package: `my.<tool>.stylix.enable` — defaults to
    `my.stylix.enable && my.<tool>.enable`. Lets you theme everything but opt one
    tool out (or vice-versa).

This replaces the bespoke `modules/stylix/users/ghostty.nix` target; the
per-user stylix *foundation* (`modules/stylix/users/options.nix`, the
colors/polarity/fonts override surface) stays and feeds `theme`.

## Values migration

`modules/users/jasonbk/programs/*.nix` (which set
`users.users.jasonbk.programs.<tool>`) move to `modules/my/values/jasonbk.nix`
setting `users.users.jasonbk.my.<tool>` — same per-user scope, new namespace.
Standalone-HM hosts set the equivalent `my.<tool>` (system = single user) in
their host config.

## Flake wiring

- `modules/default.nix` drops `./programs` and `./stylix/users`-as-is; the new
  tree is wired by having each platform partition import the matching platform
  module:
  - darwin configs import `modules/my/nix-darwin.nix` (+ `values/jasonbk.nix`).
  - nixos configs import `modules/my/nixos.nix` (+ `values/jasonbk.nix`).
  - standalone home configs import `modules/my/home-manager.nix`.
- The nvf `specialArgs.neovimConfiguration` is set per-configuration in each
  partition's `default.nix`.
- Stylix theming is wired generically by the framework (see "Stylix
  integration"); `modules/stylix/users/ghostty.nix` is removed in favor of
  ghostty's in-def `stylix` theme mapper, while `modules/stylix/users/options.nix`
  (the per-user override foundation) is kept and feeds the resolved `theme`.

## Deletions (scope: move + rewire + delete)

- `modules/programs/` (all migrated tools) → replaced by `modules/my/programs/`.
- `modules/users/` → replaced by `modules/my/values/`.
- Legacy duplicates: `modules/darwin/programs/git.nix`, `.../nvf.nix`,
  `modules/home-manager/jasonbk/programs/{git,jujutsu,...}` for migrated tools.
- `modules/programs/tests/` → `modules/my/tests/`.

Remaining host-by-host HM removal for not-yet-migrated tools stays as the open
issues (#43–#57).

**Darwin per-user is ready now (supersedes stale `WRAPPERS.md`):** review (S4)
verified nix-darwin **does** support `users.users.<n>.packages`
(`/etc/profiles/per-user/<name>`), and that per-user wrappers shadow system ones
in PATH on **both** NixOS (`mkAfter` on `/run/current-system/sw`) and nix-darwin
(`mkOrder 900` on the per-user profile). So `WRAPPERS.md`'s "darwin's
`users.users` has no packages yet — cutover later" note is obsolete and this
design installs darwin per-user wrappers directly; `WRAPPERS.md` is rewritten to
the `my.*` convention. Darwin's `users.knownUsers`/`uid` requirements still
apply.

## Testing

`modules/my/tests/*.nix` are `{pkgs, inputs ? null}` -> VM test, auto-registered
(check name = file name), merged into `perSystem.checks`. Assert **plumbing**,
not real defaults (repo rule):

- `<tool>-wrapper`: sentinel through `settings` -> read back via the wrapped
  binary (ports the existing `jujutsu/git/gh/ghostty-stylix` tests).
- `override-precedence` (new, load-bearing): system `my.git` + a user with
  `users.users.<n>.my.git.enable` and a distinct sentinel; assert the user's
  shell resolves the per-user wrapper (per-user shadows system) and that
  cascade deep-merge produced system+user settings.
- `nvf-specialarg` (new): assert a clear eval error when `my.nvf.enable` and no
  `neovimConfiguration` specialArg; and a successful build when provided.

## Execution

1. **Foundation (serial):** `lib.nix`, `system-scope.nix`, the 3 platform
   modules, tests harness; migrate **jujutsu** as the reference; wire one host;
   `nix flake check` + a representative build green.
2. **Fan-out (parallel, frozen contract):** git, gh, starship, nushell, ghostty
   (+ stylix target retarget), nvf (specialArg + per-channel partition wiring),
   fish, direnv, fd/rg; `values/jasonbk.nix`; host rewiring + old-module
   deletion.
3. **Workstream B (parallel, independent):** rewrite issue #36 and the linked
   unfinished issues to the `my.*` convention.

[#36]: https://github.com/jasonboukheir/dotfiles/issues/36
[#39]: https://github.com/jasonboukheir/dotfiles/issues/39
