# diffview-plus.nvim hasn't reached the 26.05 channels yet; pull just this one
# plugin from unstable so nvf's git/jj merge+diff tooling (body.nix) can rely on
# the -plus fork's :DiffviewMergeFiles / :DiffviewDiffDirs commands. Pure-lua
# plugin, so building it against unstable's tree is inert.
# TODO: drop once diffview-plus-nvim lands in nixpkgs-26.05.
{inputs}: final: prev: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in {
  vimPlugins = prev.vimPlugins // {inherit (unstable.vimPlugins) diffview-plus-nvim;};
}
