# The `programs.nvf` surface, shared by the system entry (./default.nix) and the
# home-manager entry (./home-manager.nix) so both contexts expose the same
# options.
{lib, ...}: {
  options.programs.nvf = {
    enable = lib.mkEnableOption "nvf-built neovim (nvf's standalone builder)";

    neovimConfiguration = lib.mkOption {
      type = lib.types.raw;
      description = ''
        nvf's `lib.neovimConfiguration` builder, taken from the nvf flake input
        whose nixpkgs matches this host's channel (e.g. `inputs.nvf-darwin` or
        `inputs.nvf-nixos-unstable`). Required when `enable` is set — there is
        deliberately no default, so each host opts in to a specific nvf input.
      '';
    };

    meta = {
      enable = lib.mkEnableOption "meta.nvim plugin (Myles, BigGrep, Hg, LSP, etc.)";

      pluginPath = lib.mkOption {
        type = lib.types.str;
        default = "/usr/share/fb-editor-support/nvim";
        description = "Path to the meta.nvim plugin directory.";
      };
    };

    settings = lib.mkOption {
      type = lib.types.deferredModule;
      default = {};
      description = ''
        Extra nvf module merged into the standalone build. Stylix's nvf target
        writes the base16 colorscheme here; arbitrary `vim.*` tweaks work too.
      '';
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The wrapped neovim package nvf built from the settings.";
    };
  };
}
