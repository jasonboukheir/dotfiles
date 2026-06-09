VERDICT: NEEDS_REVISION

## Summary Assessment

The reorganization (`modules/my/`, single program-def contract, thin platform consumers) is sound and the PATH-precedence claim holds on **both** NixOS and nix-darwin, but the design's central cascade mechanic — "inject the system value as a whole-attrset `mkDefault` to get deep-merge" — is **provably wrong** (it defeats deep-merge exactly like `default =` does), and the nvf `specialArgs` plumbing cannot work where the design places it because plain `submodule`s do not receive the parent's `specialArgs`.

## Critical Issues (must fix)

### C1. The cascade deep-merge claim is false as specified (whole-attrset `mkDefault`)

Design lines 122-124 state the per-user submodule injects the system value as `lib.mkDefault config.my.<tool>.<opt>` and asserts: *"Because freeform `formats.*` / `attrsOf` options merge across definitions, the user's explicit settings deep-merge over the inherited system settings… Pure option `default =` would replace whole attrsets, defeating deep-merge — hence `mkDefault` definitions, not defaults."*

This reasoning is backwards. I verified empirically against the repo's own nixpkgs (`pkgs.formats.toml {}` type, three-module `evalModules`):

- **Whole-attrset `mkDefault` (what the design specifies):**
  system `mkDefault { init.defaultBranch="main"; user.name="sys"; }` + user `{ user.email="a@x"; }`
  → result `{ user = { email = "a@x"; }; }`. **The system's `init.defaultBranch` and `user.name` are silently lost.**

  A `mkDefault` whole-attrset is a *single lower-priority definition*; the module system's priority filter drops it entirely the moment a higher-priority (normal) definition of the same option exists. Deep-merge across definitions only happens between definitions of **equal** priority. So whole-attrset `mkDefault` has the *exact* defeating-deep-merge problem the design ascribes to `default =`.

- **Equal-priority injection** (`config.settings = systemValue;` with no `mkDefault`): deep-merges correctly (`{ init.defaultBranch="main"; user={email="a@x"; name="sys"}; }`) — **but** if the user sets a scalar the system also set (e.g. both set `ui.editor`), evaluation **fails** with a conflicting-definition error. This breaks the design's own promise (line 124) that "scalars are replaced" by the user.

- **Per-leaf recursive `mkDefault`** (recurse into the system attrset and wrap each *leaf* in `mkDefault`): the only approach that gives **both** deep-merge of nested keys **and** user-wins-on-scalars. Verified: `{ init.defaultBranch="main"; user={email="a@x"; name="sys"}; }` with user override of a leaf succeeding.

**Required fix:** the cascade must recurse the system config and apply `mkDefault` per leaf (a `mapAttrsRecursive`-style wrap), not `mkDefault` the whole attrset. This is non-trivial for freeform types because the framework must walk arbitrary `formats.*` attrsets (and handle lists — a `mkDefault`'d list leaf is *replaced*, not concatenated, which is probably the desired behavior but should be stated). The design should specify this algorithm explicitly; it is the load-bearing mechanic and the current spec produces silently-wrong wrappers.

### C2. `specialArgs` are not available inside the per-user submodule where `build`/`finalPackage` run

Design lines 68, 81-87 define `build = { cfg, specialArgs }: …` and `finalPackage = build { cfg = <this scope's cfg>; inherit specialArgs; }`, computed inside the per-user submodule (and the system scope). I verified that a plain `lib.types.submodule` calls `evalModules` with `specialArgs ? {}` defaulted to empty (`lib/types.nix` `submoduleWith`, ~line 1437) — the parent `nixosSystem`/`darwinSystem` `specialArgs` (where `inputs`/`neovimConfiguration` live) are **not** propagated into `users.users.<name>` submodules. A submodule that takes `{ specialArgs, … }` or `{ neovimConfiguration, … }` as a module arg throws `attribute … missing`.

Two consequences:
- nvf as a **per-user** wrapper cannot read `specialArgs.neovimConfiguration` at all under the proposed shape.
- Even at **system scope**, `finalPackage` computed *inside an option declaration* (`finalPackage = build {…specialArgs}`) only works if the framework explicitly threads `specialArgs` into the module that declares the option. System-scope modules do receive specialArgs (top-level), so this is salvageable there; the per-user submodule is not.

**Required fix:** either (a) declare the per-user surface with `submoduleWith { specialArgs = { inherit neovimConfiguration …; }; }` so the submodule receives them, or (b) have the *top-level* platform module (which does get specialArgs) read `neovimConfiguration` and inject it into each user submodule's config via `_module.args`, or (c) keep nvf out of the per-user scope entirely and special-case it as system-only. The design must pick one; as written, `build { … specialArgs }` inside the submodule is an eval error. (I confirmed the top-level-reads-then-injects pattern works.)

### C3. fish cannot be a pure per-user wrapper — real system-level support is required

The design (lines 179-196) claims fish's `interactiveShellInit`, completions, `plugin-git`, starship init, carapace, vivid `LS_COLORS`, and `direnv hook fish` all "bake into a config dir the wrapped fish points at" with shell registration merely "out of scope." Reading the upstream NixOS fish module (`nixpkgs/nixos/modules/programs/fish.nix`) shows this hand-waves a genuine gap:

- fish only auto-sources `/etc/fish/config.fish` and the generated `shellInit`/`loginShellInit`/`interactiveShellInit` **when fish is the login/interactive shell**. A wrapped fish binary on `PATH` invoked as `fish` still reads `$__fish_config_dir`/`/etc/fish`, but the *system* `interactiveShellInit` (starship init etc.) lives in `/etc/fish/interactiveShellInit.fish` generated by the system module — not in the wrapper. The current repo (`modules/programs/fish.nix`) deliberately puts `starship init fish` into `programs.fish.interactiveShellInit` at **system** scope precisely because that is where fish sources it.
- The module generates system completions into `/etc/fish/generated_completions` (a `buildEnv` over all `systemPackages`) and links vendor dirs via `pathsToLink` (`vendor_conf.d`/`vendor_completions.d`/`vendor_functions.d`). `plugin-git`'s functions ride in via the *system profile's* `share/fish/vendor_functions.d` — the current `fish.nix` installs it to `environment.systemPackages` for exactly that reason. Pointing a wrapper's `$__fish_config_dir` elsewhere does not reproduce the vendor-path machinery; you would have to re-implement `fish_complete_path`/`fish_function_path` assembly inside the wrapper.
- The module appends fish to `environment.shells` (→ `/etc/shells`) and that, plus `users.users.<n>.shell`, is what makes fish a usable login shell. The design correctly scopes these out — but combined with the above, "`my.fish` only configures+installs the package" leaves the *interactive experience* (prompt, completions, hooks) dependent on system state that `my.*` refuses to set. That is not merely "shell registration out of scope"; it's the core feature set.

`direnv` is genuinely simpler — a baked `direnvrc`/`direnv.toml` plus the `direnv hook fish` line living in fish's init is plausible — but it inherits fish's problem: the hook only runs if fish actually sources the wrapper's init.

**Required fix:** the design should either (a) explicitly keep a thin system-level fish integration module (`/etc/fish` init + vendor `pathsToLink` + completion generation) outside `my.*` and have `my.fish` only own the *config content* it feeds in, or (b) drop the claim that fish/direnv become "ordinary package programs with NO system support" and document precisely which system hooks remain. As written, a per-user `my.fish` wrapper with no system module yields a fish with no prompt, no vendor completions, and no plugin-git for any user who is not also covered by the (now-deleted) system fish module.

### C4. The design misrepresents the stylix precedent it leans on

Design lines 102-103 and 124 cite `modules/stylix/users/` as the precedent for the cascade and imply it injects system values as config-level `mkDefault` definitions. It does not. `modules/stylix/users/options.nix` reads the **top-level** `config.stylix.*` / `config.lib.stylix.colors` (the perUser submodule closes over the outer module's `config`) and uses them as **`default =`** values on each per-user option (lines 27-103), guarded with `or` fallbacks. The only `mkDefault` use is in the *target* (`ghostty.nix` line 49: `lib.mapAttrs (_: lib.mkDefault) themed`) which writes **per-leaf** `mkDefault` into the wrapper's `settings` — i.e. precisely the per-leaf approach C1 says the cascade needs, **not** a whole-attrset mkDefault.

So the precedent actually contradicts the design's stated mechanic and supports the C1 fix. The design should be rewritten to match what stylix really does (top-level `config` read + per-leaf `mkDefault` at the target), and stop citing it as justification for whole-attrset `mkDefault`.

## Suggestions (nice to have)

### S1. Collapse the two option scopes into one shared submodule type

The design declares the same option set twice (system scope on the platform module + per-user scope on the `users.users` submodule) and a `lib.nix` framework to keep them in sync. Given C2 already pushes you toward `submoduleWith` for the per-user surface, consider defining **one** `programModule = { lib, pkgs, specialArgs }: submoduleWith { specialArgs; modules = [ … ]; }` and using it both as the type of `users.users.<n>.my` and, for the system scope, as a single `my` submodule instance. This removes the duplication the `lib.nix` framework exists to manage and makes the cascade a single well-defined operation (merge two evaluated configs) rather than two parallel option trees.

### S2. `finalPackage` as a readOnly option computed by `build` is fine — but keep `build` pure

Computing `finalPackage` from sibling options in the same submodule is sound (no recursion risk: `build` reads `cfg.*` which are independent options; `finalPackage` is not read by them). The risk is only if `build` reads `config` outside its own `cfg`/`specialArgs` — keep the contract `build = { cfg, specialArgs }` strictly closed over those two and it's safe. Add this as an explicit rule.

### S3. fd/rg inconsistency with current repo

Design lines 203-205 make fd/rg trivial `my.<tool>` programs (`build = cfg.package`). Today `modules/programs/fd.nix` is `environment.systemPackages = [pkgs.fd]` (system-wide, not per-user). That's a behavior change (fd moves from always-system to enable-gated). Fine, but call it out in the migration notes so fd/rg don't silently disappear from hosts that don't opt in.

### S4. Darwin per-user cutover is actually ready — update the stale WRAPPERS.md caveat

`docs/WRAPPERS.md` (lines 62-64) says "darwin's `users.users` has no packages yet — its cutover comes later," and the per-user values are currently wired only through `modules/nixos/default.nix` (`../users`), not darwin. I verified nix-darwin **does** support `users.users.<n>.packages` (`modules/users/default.nix` builds `/etc/profiles/per-user/<name>` via `environment.etc`, lines 333-341). The design's plan to install darwin per-user wrappers there is feasible today — but the design should explicitly note it is *superseding* that WRAPPERS.md caveat, and that darwin's `users.knownUsers`/`uid` requirements (modules/darwin/users.nix) still apply.

### S5. nvf assertion-when-missing must not eval-error when nvf is disabled

Design lines 164-167 want a clear assertion when `my.nvf.enable && neovimConfiguration` is absent. Ensure the `neovimConfiguration` read is lazy/guarded (the current `config.nix` only touches it under `lib.mkIf cfg.enable`, which is correct). With the C2 fix, the assertion should fire from the top-level module that owns specialArgs, asserting `cfg.enable -> (specialArgs ? neovimConfiguration)`, not from inside a submodule that can't see specialArgs.

### S6. nvf `neovimConfiguration` is currently set in host files, not partitions

Design lines 168-174 say the flake partitions set the specialArg. Today it is set in **host** files (`hosts/{thebeast,brutus,litus}/nvf.nix`, `modules/darwin/programs/nvf.nix`) as a `programs.nvf.neovimConfiguration` *module option*, and the nvf inputs are declared per-partition `flake.nix` (`modules/flake/{nixos,home,darwin}/flake.nix`), not the root `flake.nix`. Moving to `specialArgs` requires editing each partition's `default.nix` `mkHost`/`nixosSystem` call (darwin's `mkHost` uses a shared `specialArgs` for *both* macs, which is fine since both use `nvf-darwin`; nixos sets specialArgs per-host so the unstable/stable split — `thebeast` uses `nvf-nixos-unstable`, others `nvf-nixos` — maps cleanly). Doable, but the design should name the exact files and note darwin's shared-specialArgs vs nixos's per-host-specialArgs asymmetry.

## Verified Claims (confirmed correct against the code)

- **PATH precedence on NixOS:** `environment.profiles` orders `/etc/profiles/per-user/$USER` before `/run/current-system/sw` (`nixpkgs/nixos/modules/config/users-groups.nix` lines 1000-1005 at normal priority; `nixos/modules/programs/environment.nix` line 28 `mkAfter`s `/run/current-system/sw`). PATH is built in profile order, so the per-user wrapper shadows the system one. **Correct.**
- **PATH precedence on nix-darwin:** `environment.profiles` uses `mkOrder 900` for `/etc/profiles/per-user/$USER` vs default (1000) for `/run/current-system/sw` (nix-darwin `modules/users/default.nix` line 343, `modules/environment/default.nix` lines 178-187). `systemPath = [(makeBinPath cfg.profiles)]` preserves ascending order, so per-user precedes system in PATH. **Correct on darwin too** (note NIX_PROFILES is reverse-ordered, but PATH is not — the wrapper shadowing relies on PATH, which is correct).
- **nix-darwin supports `users.users.<n>.packages`:** builds `/etc/profiles/per-user/<name>` via `environment.etc` (`modules/users/default.nix` 333-341). The design treating darwin per-user installs as working today is **correct** and supersedes the stale WRAPPERS.md note (see S4).
- **`mkWrapped` primitive** (`modules/nixpkgs/overlays/mkWrapped.nix`) is a `symlinkJoin` + `wrapProgram --set/--prefix PATH/--add-flags`, shell-escaped, with `passthru.unwrapped`/`meta.mainProgram`. Staying as-is is fine; it supports every program-def's `build`.
- **Single shared `modules/programs` tree** is imported by both NixOS and darwin via `modules/default.nix` (`./programs`), matching the design's `system-scope.nix` shared-between-platforms approach.
- **Per-leaf `mkDefault` deep-merges correctly** with a user's explicit settings while letting the user win on scalars — empirically verified; this is the correct cascade mechanism the C1 fix should adopt (and what stylix's ghostty target already does).
- **Test harness auto-registration** (`modules/programs/tests/default.nix`) maps every non-`default.nix` `*.nix` to a check named by filename and threads `{pkgs, inputs}`; `inputs` reaches the nvf tests (`nvf-polarity.nix` uses `inputs.nvf-nixos.lib.neovimConfiguration`). Moving to `modules/my/tests/` with the same harness is straightforward, and a `nvf-specialarg`/`override-precedence` test is implementable on this harness (override-precedence needs a multi-user NixOS VM asserting `su -l user2` resolves the per-user wrapper — feasible).
- **gh's `GH_CONFIG_DIR` caveat** (design keeps only `GH_EDITOR`) matches `modules/programs/gh.nix` — auth must stay in the real config dir; the design preserves this.
