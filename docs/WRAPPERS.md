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
  pkg = pkgs.jujutsu;             # package to wrap
  name = "jj";                    # binary in $out/bin to wrap; defaults to mainProgram/pname
  env.JJ_CONFIG = configFile;     # attrs -> `--set KEY VALUE`
  flags = ["--no-pager"];         # list -> `--add-flags`
  extraPaths = [pkgs.git-lfs];    # list of pkgs -> `--prefix PATH` (subcommands, helpers)
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
consts), so config is overridden through `settings` rather than by editing the
wrapper.

## Exposure surface

Wrappers are **per-user**, mirroring what home-manager gave us. NixOS has no
`users.users.<name>.programs`, so a capability module under `modules/programs/`
declares that surface itself (a module-merge onto the `users.users.<name>`
submodule) and, when enabled, pushes the built wrapper into that user's
`users.users.<name>.packages` — installed in the user's environment, not
system-wide.

- **Capability** (`modules/programs/<tool>.nix`): declares
  `users.users.<name>.programs.<tool>.{enable,settings}` and wires `.packages`.
  Tool-centric, built once, identity-free.
- **Per-user values** (`modules/users/<name>.nix`): sets
  `users.users.<name>.programs.<tool> = {enable; settings;}`. The
  home-manager-`jasonbk` replacement; wired in via `modules/nixos` (darwin's
  `users.users` has no `packages` yet — its cutover comes later).

Standalone hosts (`work-devserver`, `jasonbk-fedora`) have no system layer and
are handled separately (see [#39]).

## Reference example: jujutsu

`modules/programs/jujutsu.nix` is the cleanest case — a single `JJ_CONFIG` file.
A user opts in and tunes it via the per-user surface:

```nix
users.users.jasonbk.programs.jujutsu = {
  enable = true;                  # adds the wrapper to jasonbk's packages
  settings.ui.editor = "nvim";    # tunable; baked into that user's JJ_CONFIG
};
```

## git: `formats.gitIni` + git-lfs + flattened signing

`modules/programs/git.nix` bakes `settings` (a `formats.gitIni` attrset) into
`GIT_CONFIG_GLOBAL`, folds `ignores` in as a generated `core.excludesFile`, and
— when `lfs.enable` (default) — puts `git-lfs` on the wrapper PATH (`extraPaths`)
and bakes the `filter.lfs.*` filters into the config. It also keeps the existing
system-level `programs.git` (NixOS module) so git stays available system-wide.

home-manager gated ssh signing on `programs.ssh`/`_1password` cross-module
conditionals. Wrappers have no such cross-talk, so the per-user values
(`modules/users/jasonbk/programs/git.nix`) **flatten** the conditional: signing
keys and the `op-ssh-sign` program path are written straight into `settings`.

## gh: `GH_EDITOR`, not `GH_CONFIG_DIR`

`gh auth login` writes `hosts.yml` into `GH_CONFIG_DIR`, so pointing that var at
a read-only store path (the `JJ_CONFIG`-style move) would break auth — the one
thing the issue says must keep working. `modules/programs/gh.nix` therefore only
pins the editor via `GH_EDITOR` and leaves `GH_CONFIG_DIR` (config + auth) in the
real `~/.config/gh`. The `settings` option mirrors gh's config shape, but only
`editor` is wired.

## ghostty: `--config-file` + stylix theming

`modules/programs/ghostty.nix` bakes `settings` into a `writeText` config and
loads it via `flags = ["--config-file=${file}"]`. List values render as repeated
`key = item` lines, so `palette = ["0=#…" "1=#…"]` becomes ghostty's repeated
`palette = N=#…` form. The user's own `~/.config/ghostty/config` still loads, so
hand edits win on conflicts.

## shell stack: starship/nushell wrappers + native fish/direnv

The shell stack ([#42]) splits by tool. HM auto-emitted the shell-init hooks
(starship init, direnv hook, carapace completer, vivid `LS_COLORS`); with HM gone
each is hand-concatenated into the right place.

- **starship** (`modules/programs/starship.nix`): a `JJ_CONFIG`-style per-user
  wrapper — `settings` → `formats.toml` → `STARSHIP_CONFIG`. It only pins the
  prompt config; the shells run `starship init <shell>` themselves.
- **nushell** (`modules/programs/nushell/`): the wrapper bakes `config.nu`
  (loaded via `--config`) and a generated `env.nu` (via `--env-config`). `env.nu`
  carries the gotcha hooks — vivid `$env.LS_COLORS` and `starship init nu` into
  nushell's vendor-autoload dir — and carapace rides on the wrapper PATH for the
  `config.nu` external completer. Flags, not `XDG_CONFIG_HOME`, so child
  processes don't inherit a redirected config home. vivid defaults to the `ansi`
  theme so `LS_COLORS` follows the terminal's 16 ANSI slots (themed from base16
  by stylix) instead of pinning a separate colour scheme.
- **fish** (`modules/nixos/programs/fish.nix`): native `programs.fish` at the
  system layer. `interactiveShellInit` concatenates `starship init fish` (guarded
  on starship being on a user's PATH, since it's a per-user wrapper); `plugin-git`
  rides in via the system profile's `share/fish/vendor_*`.
- **direnv** (`modules/nixos/programs/direnv.nix` + `modules/darwin/programs/direnv.nix`):
  native `programs.direnv` + `nix-direnv`, enabled system-wide on every host
  with a system layer (split per-platform like `fish`); the module emits its own
  `direnv hook fish` (and bash/zsh). Standalone home-manager hosts keep direnv
  via HM (no system layer to hook — see [#39]).
- **zsh**: no wrapper — it stays gated behind `programs.zsh.enable`, dropped
  where unused.

`starship-wrapper`/`nushell-wrapper` assert the per-user plumbing
(`settings → STARSHIP_CONFIG`; `config.nu`/`env.nu` → `--config`/`--env-config`,
vivid `LS_COLORS`, carapace on PATH, the baked `starship init nu`).
`shell-init-hooks` boots native fish + direnv with the per-user starship wrapper
and asserts the concatenated hooks are present in `/etc/fish`, the plugin-git
vendor functions load, and direnv/starship resolve.

## stylix: per-user theming without the HM stylix module

home-manager's stylix module turned the **system** stylix config
(`stylix-nixos`/`stylix-darwin`) into per-`~/.config` color files. Dropping HM
([#38]) drops those, so `modules/stylix/users/` re-creates the mechanism on the
`users.users.<name>` submodule — the same surface the wrappers already extend.

- **Foundation** (`modules/stylix/users/options.nix`): declares
  `users.users.<name>.stylix.{enable,polarity,colors,fonts,opacity}`. Each option
  **defaults from the system stylix config** — `colors` from
  `config.lib.stylix.colors`, `polarity`/`fonts`/`opacity`/`enable` from
  `config.stylix.*` — so a user inherits the system theme but can override any of
  them (e.g. `users.users.<name>.stylix.colors` for a different base16 scheme).
  The system reads are guarded, so importing the foundation onto a host with no
  system stylix is a no-op rather than an eval error. `stylix.cursor` is a
  NixOS-only option (the darwin stylix module never declares it), so the
  per-user `cursor.{name,package,size}` is a `nullOr` that inherits the themed
  system cursor on Linux and resolves to `null` on darwin — a cursor target
  keys off `cursor.name != null` and stays inactive where there is no cursor.
- **Targets** (`modules/stylix/users/<app>.nix`): mirror HM's
  `stylix.targets.<app>`. A target declares
  `users.users.<name>.stylix.targets.<app>.enable` (defaulting to the user's
  `stylix.enable`) and, when both it and the app wrapper are enabled, writes the
  palette into that wrapper's `settings` via `lib.mkDefault` — so the user's own
  `settings` still win. `ghostty.nix` is the first target: it maps base16 →
  `background`/`foreground`/`selection-*`/`cursor-*` and the 16 ANSI `palette`
  slots.

This keeps the wrapper (a tool) and the theme (a target) separate, exactly as
upstream stylix splits `programs.<app>` from `stylix.targets.<app>`.

## Testing the convention

`modules/programs/tests/jujutsu-wrapper.nix` (flake check `jujutsu-wrapper`) is
a NixOS VM test that asserts the **plumbing**, not the config: it sets a sentinel
through `settings` and reads it back via the wrapped `jj`, proving
`settings → formats.toml → JJ_CONFIG → jj`. It deliberately does not assert any
real default, so changing the config never touches the test.

```
nix build .#checks.x86_64-linux.jujutsu-wrapper
```

`git-wrapper` and `gh-wrapper` follow the same shape: `git-wrapper` also asserts
`git-lfs` resolves on the wrapper PATH and the lfs filter is baked; `gh-wrapper`
asserts the editor is pinned as `GH_EDITOR` and that `GH_CONFIG_DIR` is *not*
touched (so auth stays in the real config dir).

`ghostty-stylix` proves the per-user stylix path end-to-end: it feeds a set of
arbitrary base16 ids into `users.users.<name>.stylix.colors`, then asserts the
wrapper injects a baked `--config-file` whose rendered config carries those ids
on the right ghostty keys, and that `ghostty +show-config` parses the theme and
resolves the palette. Like the others it asserts the **plumbing**
(`stylix.colors → target → ghostty.settings → --config-file → ghostty`), never a
specific scheme.

Each `*.nix` in `modules/programs/tests/` is a `{pkgs, inputs ? null}` function
returning a VM test; `modules/programs/tests/default.nix` auto-registers them
all (check name = file name). These run against a plain nixpkgs, so any system
flake with a linux `pkgs` merges them into `perSystem.checks`:

```nix
checks = import ../../../modules/programs/tests {inherit pkgs inputs;};
```

[#36]: https://github.com/jasonboukheir/dotfiles/issues/36
[#39]: https://github.com/jasonboukheir/dotfiles/issues/39
