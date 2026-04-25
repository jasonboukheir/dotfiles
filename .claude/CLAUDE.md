This is a nix flakes project.
- RULE: use nix with flakes to run commands, validate config changes, build, and investigate source info. `nix run` and `nix shell` instead of `nix-run` or `nix-shell`
- prefer variables instead of hardcoded magic values (including paths).
- consider config options instead of const variables.
- always see if there is an existing option that can be used to simplify the problem, e.g. instead of writing files to /etc to setup nginx, see if there is an option in services.nginx.
