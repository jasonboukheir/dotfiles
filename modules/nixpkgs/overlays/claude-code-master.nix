# Claude-only import from nixpkgs-master: ride ahead of unstable so a new model
# is available before its claude-code bump reaches the unstable channel. Only
# `claude-code` is swapped out for master's; the host keeps its own channel for
# everything else (master is never a host's base pkgs).
{inputs}: final: _prev: {
  claude-code =
    (import inputs.nixpkgs-master {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    })
    .claude-code;
}
