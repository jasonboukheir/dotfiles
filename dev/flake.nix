{
  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = {
    nixpkgs-unstable,
    agenix,
    ...
  }: let
    forAllSystems = nixpkgs-unstable.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs-unstable {inherit system;};
      agenixPkg = agenix.packages.${system}.default;
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
            current_host=$(hostname -s 2>/dev/null || uname -n | cut -d. -f1)
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
        buildInputs = [
          pkgs.nixd
          pkgs.alejandra
          agenixPkg
          secret
        ];
      };
    });
  };
}
