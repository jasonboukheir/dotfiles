{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    agenix,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      agenixPkg = agenix.packages.${system}.default;

      # Shared snippet: populates two bash arrays for the current host —
      #   flakes=(...)       the flake roots to walk (update-flakes, check)
      #   host_tests=(...)   attr names under flake.checks.<system> that
      #                      apply to this host (consumed by `test`)
      # Sourced by every wrapper that needs host-aware dispatch. Arrays are
      # kept as shell-local state rather than exported env vars so the same
      # snippet can be evaluated from any subshell without leaking stale
      # host metadata across `nix develop` sessions.
      hostFlakesSnippet = ''
        repo_root=$(git rev-parse --show-toplevel)
        host=$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || uname -n | cut -d. -f1)

        # Meta devservers get per-allocation hostnames (devvm1234, devbig5,
        # devgpu9, ...); they all share the work-devserver home config.
        case "$host" in
          devvm*|devbig*|devgpu*) host=work-devserver ;;
        esac

        flakes=("$repo_root")
        host_tests=()

        case "$(uname -s)" in
          Linux)
            flakes+=("$repo_root/modules/flake/dev")
            # Include nixos only if the current host is declared as a
            # nixosSystem in modules/flake/nixos/default.nix. work-devserver is
            # Linux but home-manager-only, so it skips this branch.
            if grep -qE "^[[:space:]]+''${host}[[:space:]]*=[[:space:]]*inputs\.[A-Za-z0-9_-]+\.lib\.nixosSystem" \
                 "$repo_root/modules/flake/nixos/default.nix" 2>/dev/null; then
              flakes+=("$repo_root/modules/flake/nixos")
            fi
            # home-manager-only Linux hosts (work-devserver, fedora) declare a
            # homeConfigurations."jasonbk@<host>" entry in
            # modules/flake/home/default.nix. Their inputs live in that flake.
            if grep -qF "homeConfigurations.\"jasonbk@''${host}\"" \
                 "$repo_root/modules/flake/home/default.nix" 2>/dev/null; then
              flakes+=("$repo_root/modules/flake/home")
            fi
            ;;
          Darwin)
            flakes+=("$repo_root/modules/flake/darwin")
            ;;
          *)
            echo "unsupported OS $(uname -s)" >&2
            exit 1
            ;;
        esac

        # Host-specific nixosTest attrs. Each name resolves to
        # flake.checks.<system>.<name> in the root flake.
        case "$host" in
          thebeast)
            host_tests+=("thebeast-session")
            ;;
        esac
      '';

      update-flakes = pkgs.writeShellApplication {
        name = "update-flakes";
        runtimeInputs = [pkgs.git pkgs.nix pkgs.nettools pkgs.gnugrep];
        text = ''
          ${hostFlakesSnippet}

          for f in "''${flakes[@]}"; do
            echo "==> $f"
            nix flake update --flake "$f"
          done
        '';
      };

      rebuild = pkgs.writeShellApplication {
        name = "rebuild";
        runtimeInputs = [pkgs.git pkgs.nix pkgs.nettools];
        text = ''
          repo_root=$(git rev-parse --show-toplevel)
          host=$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || uname -n | cut -d. -f1)

          # Meta devservers get per-allocation hostnames (devvm1234, devbig5,
          # devgpu9, ...); they all share the work-devserver home config.
          case "$host" in
            devvm*|devbig*|devgpu*) host=work-devserver ;;
          esac

          case "$(uname -s)" in
            Linux)
              if grep -qE "^[[:space:]]+''${host}[[:space:]]*=[[:space:]]*inputs\.[A-Za-z0-9_-]+\.lib\.nixosSystem" \
                   "$repo_root/modules/flake/nixos/default.nix" 2>/dev/null; then
                echo "==> nixos-rebuild switch ($host)"
                exec sudo nixos-rebuild switch --flake "$repo_root#$host" "$@"
              fi
              # Non-NixOS Linux (e.g. work-devserver): home-manager only.
              echo "==> home-manager switch (jasonbk@$host)"
              exec home-manager switch --flake "$repo_root#jasonbk@$host" "$@"
              ;;
            Darwin)
              echo "==> darwin-rebuild switch ($host)"
              exec sudo darwin-rebuild switch --flake "$repo_root#$host" "$@"
              ;;
            *)
              echo "rebuild: unsupported OS $(uname -s)" >&2
              exit 1
              ;;
          esac
        '';
      };

      bump = pkgs.writeShellApplication {
        name = "bump";
        runtimeInputs = [update-flakes rebuild];
        text = ''
          update-flakes
          rebuild "$@"
        '';
      };

      format = pkgs.writeShellApplication {
        name = "format";
        runtimeInputs = [pkgs.alejandra pkgs.git];
        text = ''
          repo_root=$(git rev-parse --show-toplevel)
          exec alejandra "$@" "$repo_root"
        '';
      };

      commands = pkgs.writeShellApplication {
        name = "commands";
        runtimeInputs = [];
        text = ''
            cat <<'EOF'
          Dev shell commands:

            secret [host/]<path>     Edit an agenix secret
                                     (host defaults to current hostname)
            secret -r                Rekey current host's secrets
            update-flakes            Bump flakes relevant to this host
            rebuild [args...]        Switch system config
                                     (nixos-rebuild / darwin-rebuild / home-manager)
            bump [args...]           update-flakes + rebuild
            format                   Run alejandra over the whole repo
            check                    nix flake check on each relevant flake
                                     (eval + builds every flake.checks.* attr,
                                      including nixosTest VMs — slow)
            vm-test                  Build only this host's nixosTest checks
                                     under flake.checks.<system>.*. No-op on
                                     hosts without declared tests.
            disk <subcmd>            Drive health, SMART tests, pool drive
                                     replacement walkthrough. `disk help` for
                                     full usage. Linux-only.
            commands                 Show this help

          Per-host flake set:
            brutus, litus, thebeast  → root + modules/flake/{dev,nixos}
            work-devserver           → root + modules/flake/{dev,home}  (home-manager only)
            jasonbk-fedora-MZ0319NF  → root + modules/flake/{dev,home}  (home-manager only)
            *-macbook                → root + modules/flake/{dev,darwin}

          Per-host nixosTest checks (consumed by `vm-test`):
            thebeast                 thebeast-session

          Env overrides:
            SECRET_IDENTITY=<path>   Use a different SSH key for `secret`

          EOF
        '';
      };

      check = pkgs.writeShellApplication {
        name = "check";
        runtimeInputs = [pkgs.git pkgs.nix pkgs.nettools pkgs.gnugrep];
        text = ''
          ${hostFlakesSnippet}

          rc=0
          for f in "''${flakes[@]}"; do
            echo "==> nix flake check $f"
            nix flake check "$f" "$@" || rc=$?
          done
          exit "$rc"
        '';
      };

      vm-test = pkgs.writeShellApplication {
        name = "vm-test";
        runtimeInputs = [pkgs.git pkgs.nix pkgs.nettools];
        text = ''
          ${hostFlakesSnippet}

          if [ "''${#host_tests[@]}" -eq 0 ]; then
            echo "vm-test: no nixosTest checks declared for $host" >&2
            exit 0
          fi

          system=$(nix eval --impure --raw --expr 'builtins.currentSystem')

          rc=0
          for t in "''${host_tests[@]}"; do
            attr="checks.''${system}.''${t}"
            echo "==> nix build $repo_root#$attr"
            nix build "$repo_root#$attr" -L "$@" || rc=$?
          done
          exit "$rc"
        '';
      };

      disk = import ./disk.nix {inherit pkgs;};

      secret = pkgs.writeShellApplication {
        name = "secret";
        runtimeInputs = [agenixPkg pkgs.git pkgs.gawk pkgs.nettools];
        text = ''
          repo_root=$(git rev-parse --show-toplevel)

          # Discover which hosts have a secrets manifest.
          known_hosts=()
          for f in "$repo_root"/hosts/*/secrets/secrets.nix; do
            [ -f "$f" ] || continue
            known_hosts+=("$(basename "$(dirname "$(dirname "$f")")")")
          done
          if [ ''${#known_hosts[@]} -eq 0 ]; then
            echo "secret: no hosts/*/secrets/secrets.nix under $repo_root" >&2
            exit 1
          fi

          # Resolve target host: explicit "host/..." prefix wins over hostname.
          target_host=""
          if [ $# -ge 1 ]; then
            first_segment="''${1%%/*}"
            for h in "''${known_hosts[@]}"; do
              if [ "$first_segment" = "$h" ]; then
                target_host="$h"
                if [[ "$1" == */* ]]; then
                  rest="''${1#*/}"
                  shift
                  set -- "$rest" "$@"
                else
                  shift
                fi
                break
              fi
            done
          fi
          if [ -z "$target_host" ]; then
            current_host=$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || uname -n | cut -d. -f1)
            for h in "''${known_hosts[@]}"; do
              [ "$h" = "$current_host" ] && target_host="$h" && break
            done
          fi
          if [ -z "$target_host" ]; then
            echo "secret: no manifest for current host. Available:" >&2
            printf '  %s\n' "''${known_hosts[@]}" >&2
            echo "Use: secret <host>/<path>" >&2
            exit 1
          fi

          secrets_dir="$repo_root/hosts/$target_host/secrets"
          cd "$secrets_dir"

          if [ $# -eq 0 ]; then
            echo "secret ($target_host): pass a path (e.g. searx/env), or -r to rekey" >&2
            echo "available:" >&2
            awk '/^    "/ {gsub(/[",]/, ""); print "  " $1}' secrets.nix >&2
            exit 1
          fi

          # Override via SECRET_IDENTITY=/path/to/key on hosts without the
          # standard NixOS host key.
          host_identity="''${SECRET_IDENTITY:-/etc/ssh/ssh_host_ed25519_key}"
          if [ ! -e "$host_identity" ]; then
            echo "secret: identity $host_identity not found" >&2
            exit 1
          fi

          if [ "''${1:-}" = "-r" ] || [ "''${1:-}" = "--rekey" ]; then
            agenix_args=(-r)
          else
            target="$1"
            [[ "$target" == *.age ]] || target="$target.age"
            agenix_args=(-e "$target")
          fi

          # Stage the root-owned host key into a user-owned temp file
          # (mktemp creates it 0600). agenix runs as the user so $EDITOR
          # gets your nvim and the re-encrypted output is user-owned.
          # sudo is only invoked once, to read the key. trap cleans up
          # even on Ctrl-C or agenix failure (only SIGKILL can skip it).
          if [ -r "$host_identity" ]; then
            agenix "''${agenix_args[@]}" -i "$host_identity"
          else
            identity=$(mktemp)
            trap 'rm -f "$identity"' EXIT
            sudo cat "$host_identity" | tee "$identity" > /dev/null
            agenix "''${agenix_args[@]}" -i "$identity"
          fi
        '';
      };
    in {
      default = pkgs.mkShell {
        buildInputs =
          [
            pkgs.nixd
            pkgs.alejandra
            agenixPkg
            secret
            update-flakes
            rebuild
            bump
            format
            check
            vm-test
            commands
          ]
          # disk pulls smartmontools, memtester, cryptsetup, zfs userspace —
          # all Linux-only and only useful against a NixOS host that owns
          # real disks. Skip on darwin so the dev shell still evaluates.
          ++ nixpkgs.lib.optional pkgs.stdenv.isLinux disk;
      };
    });
  };
}
