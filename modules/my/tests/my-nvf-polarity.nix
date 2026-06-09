# nvf build plumbing: a stylix polarity comes out as `vim.o.background` in the
# wrapped neovim built by my.nvf.
{
  pkgs,
  inputs ? null,
}:
pkgs.testers.nixosTest {
  name = "my-nvf-polarity";

  nodes.machine = {lib, ...}: {
    imports = [
      ../nixos.nix
    ];

    # stylix stub so system-scope's `config.stylix` read resolves a theme.
    options.stylix = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      polarity = lib.mkOption {
        type = lib.types.str;
        default = "dark";
      };
    };

    config = {
      # the neovimConfiguration specialArg, fed as a module arg (must be under
      # `config` since this module also declares `options`).
      _module.args.neovimConfiguration = inputs.nvf-nixos.lib.neovimConfiguration;

      stylix = {
        enable = true;
        polarity = "light";
      };
      my.stylix.enable = true;
      my.nvf.enable = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("the standalone nvf build is the system nvim"):
        machine.succeed("command -v nvim")
        machine.succeed("nvim --version")

    with subtest("the stylix polarity reaches vim.o.background"):
        bg = machine.succeed(
            "HOME=/root nvim --headless '+lua io.write(vim.o.background)' '+qa!' 2>&1"
        ).strip()
        assert bg == "light", f"expected background 'light', got {bg!r}"
  '';
}
