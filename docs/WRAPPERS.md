# Hand-rolled tool wrappers

How this repo configures CLI tools without home-manager. We do **not** use
`wrapper-manager`; wrappers are hand-rolled with `pkgs.symlinkJoin` /
`pkgs.makeWrapper`, matching the `modules/darwin/programs/homebrew-casks.nix`
stub style. Part of the home-manager removal ([#36]).

## The helper: `pkgs.mkWrapped`

`lib/mkWrapped.nix` re-exposes a package's binary with baked-in environment and
flags. It is exposed as `pkgs.mkWrapped` by `modules/nixpkgs/overlays/mkWrapped.nix`.

```nix
pkgs.mkWrapped {
  pkg = pkgs.jujutsu;          # package to wrap
  name = "jj";                 # binary in $out/bin to wrap; defaults to mainProgram/pname
  env.JJ_CONFIG = configFile;  # attrs -> `--set KEY VALUE`
  flags = ["--no-pager"];      # list -> `--add-flags`
}
```

It returns a `symlinkJoin` of `pkg` with `$out/bin/${name}` wrapped, carrying
`pkg`'s `meta`/`passthru` (plus `passthru.unwrapped = pkg`). Values are shell-
escaped, so store paths and arbitrary strings are safe.

`--set` **pins** the variable: it overrides whatever the caller exports. That is
the point — the user can't drift the config out from under the wrapper.

## Where baked config lives

Generate config as a store file next to the wrapper and point the tool at it:

- env-var tools (`JJ_CONFIG`, `GIT_CONFIG_GLOBAL`, `GH_CONFIG_DIR`,
  `STARSHIP_CONFIG`, `XDG_CONFIG_HOME`) → `env.THAT_VAR = file`.
- `--config`-style tools → `flags = ["--config" "${file}"]`.

Build the file with the matching `pkgs.formats.*` generator (or `pkgs.writeText`
for non-standard formats):

```nix
configFile = (pkgs.formats.toml {}).generate "jj-config.toml" cfg.settings;
```

Tunables are exposed as module **options** (repo rule — never `let`-bound
consts), so a host overrides `programs.<tool>.settings` rather than editing the
wrapper.

## Exposure surface

Each configured wrapper is a normal package, reachable two ways:

- **System hosts** (NixOS / nix-darwin): a module under `modules/programs/`
  declares the options and adds the wrapper to `environment.systemPackages`.
- **Standalone hosts** (`work-devserver`, `jasonbk-fedora`, no system layer):
  the same module exposes a read-only `wrappedPackage` option, installed via
  `nix profile install` / `home.packages` (see [#39]).

## Reference example: jujutsu

`modules/programs/jujutsu.nix` is the cleanest case — a single `JJ_CONFIG` file:

```nix
programs.jujutsu.enable = true;            # adds the wrapper to systemPackages
programs.jujutsu.settings.ui.editor = ...; # tunable; baked into JJ_CONFIG
```

`config.programs.jujutsu.wrappedPackage` is the built `jj`, addressable for
standalone use or for `nix build`.

## Testing the convention

`modules/programs/tests/jujutsu-wrapper.nix` (flake check `jujutsu-wrapper`) is
a NixOS VM test that asserts the **plumbing**, not the config: it sets a sentinel
through `settings` and reads it back via the wrapped `jj`, proving
`settings → formats.toml → JJ_CONFIG → jj`. It deliberately does not assert any
real default, so changing the config never touches the test.

```
nix build .#checks.x86_64-linux.jujutsu-wrapper
```

Each `*.nix` in `modules/programs/tests/` is a `{pkgs, inputs ? null}` function
returning a VM test; `modules/programs/tests/default.nix` auto-registers them
all (check name = file name). These run against a plain nixpkgs, so any system
flake with a linux `pkgs` merges them into `perSystem.checks`:

```nix
checks = import ../../../modules/programs/tests {inherit pkgs inputs;};
```

[#36]: https://github.com/jasonboukheir/dotfiles/issues/36
[#39]: https://github.com/jasonboukheir/dotfiles/issues/39
