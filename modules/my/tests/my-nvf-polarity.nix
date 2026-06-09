# Proves the standalone nvf build plumbing end-to-end through the my.* surface: a
# sentinel stylix polarity comes out the far side as `vim.o.background` in the
# wrapped neovim built by my.nvf. "light" is the sentinel (the default is
# "dark"), so the test exercises the wiring rather than a default. The my.* port
# of programs/tests/nvf-polarity.nix.
#
# nvf builds via the `neovimConfiguration` specialArg (not an option), so the
# node sets it through `_module.args`. The system-scope `theme` is resolved from
# the host's `config.stylix`; my.stylix.enable turns the integration on so the
# polarity reaches the baked nvf body.
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

    # Minimal stylix stub so system-scope.nix's `config.stylix` read resolves a
    # `theme` without pulling the whole stylix module into the test.
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
      # nvf builds via the `neovimConfiguration` specialArg (not an option); feed
      # it as a module arg. Must live under `config` (a module with an explicit
      # `options`/`config` can't also have bare top-level attributes).
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
