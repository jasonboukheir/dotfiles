# nvf program definition. See ../CONTRACT.md.
#
# nvf is the special case in the my.* surface: it does NOT wrap one pkgs attr, so
# it OMITS `defaultPackage` (no `package` option is added). Instead it builds a
# wrapped neovim from nvf's per-channel `lib.neovimConfiguration` builder, which
# arrives as the `neovimConfiguration` specialArg (set per-configuration in the
# flake partitions). The whole nvf config is baked into the derivation.
#
# Self-contained: ./body.nix is the ported config body and ./package.nix is the
# ported standalone builder, so the old modules/programs/nvf can be deleted.
{
  lib,
  pkgs,
}: {
  name = "nvf";
  themeable = true;

  options = {
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
        Extra nvf module merged into the standalone build. Arbitrary `vim.*`
        tweaks work; this wins over the baked body and theme via nvf's own merge.
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    theme ? null,
    specialArgs ? {},
    ...
  }: let
    neovimConfiguration = specialArgs.neovimConfiguration or null;
    bodyModule = import ./body.nix {inherit cfg theme;};
  in
    import ./package.nix {
      inherit pkgs neovimConfiguration;
      modules = [
        bodyModule
        cfg.settings
      ];
    };

  assertions = {
    cfg,
    specialArgs,
    lib,
  }: [
    {
      assertion = (specialArgs.neovimConfiguration or null) != null;
      message = ''
        my.nvf.enable requires the `neovimConfiguration` specialArg. Set it
        per-configuration in the flake partition's default.nix:
        specialArgs.neovimConfiguration = inputs.nvf-<channel>.lib.neovimConfiguration;
      '';
    }
  ];
}
