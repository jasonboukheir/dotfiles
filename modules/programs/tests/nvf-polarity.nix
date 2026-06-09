# Proves the standalone nvf build plumbing end-to-end through the module: a
# sentinel stylix polarity comes out the far side as `vim.o.background` in the
# wrapped neovim. "light" is the sentinel (the default is "dark"), so the test
# exercises the wiring rather than a default. Mirrors the convention of the
# other wrapper tests (assert plumbing, never a specific config value).
{
  pkgs,
  inputs ? null,
}:
pkgs.testers.nixosTest {
  name = "nvf-polarity";

  nodes.machine = {lib, ...}: {
    imports = [../nvf/default.nix];

    # Minimal stylix stub so config.nix's `config.stylix.polarity` read works
    # without pulling the whole stylix module into the test.
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
      stylix = {
        enable = true;
        polarity = "light";
      };
      programs.nvf = {
        enable = true;
        neovimConfiguration = inputs.nvf-nixos.lib.neovimConfiguration;
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("the standalone nvf build is the system nvim"):
        machine.succeed("command -v nvim")

    with subtest("the stylix polarity reaches vim.o.background"):
        bg = machine.succeed(
            "HOME=/root nvim --headless '+lua io.write(vim.o.background)' '+qa!' 2>&1"
        ).strip()
        assert bg == "light", f"expected background 'light', got {bg!r}"
  '';
}
