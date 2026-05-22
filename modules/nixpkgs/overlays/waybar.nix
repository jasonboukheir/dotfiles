final: prev: {
  # TODO: drop once nixpkgs ships a waybar release containing
  # https://github.com/Alexays/Waybar/pull/5013 (merged 2026-05-04 to master,
  # not in 0.15.0). Without it, hyprland/workspaces on-click=activate sends
  # legacy `dispatch workspace N` which Hyprland under configType="lua"
  # rejects as invalid Lua. PR #5013 probes Hyprland once and routes through
  # hl.dsp.* when in Lua mode. The PR doesn't apply cleanly to 0.15.0 as a
  # patch (master has drifted), so we pin src to the merge commit instead.
  # cavaSupport is disabled because the nixpkgs derivation hard-codes a
  # libcava version path that doesn't match master's wrap file.
  waybar = (prev.waybar.override {cavaSupport = false;}).overrideAttrs (old: {
    version = "0.15.0-unstable-2026-05-04";
    src = final.fetchFromGitHub {
      owner = "Alexays";
      repo = "Waybar";
      rev = "05945748dccce28bf96d26d8f64a9e69a8dd49ba";
      hash = "sha256-51R3mIt8cLNvh/X5qe9vOqeJCj0U9KRyemVE5y+OhiU=";
    };
    doInstallCheck = false;
  });
}
