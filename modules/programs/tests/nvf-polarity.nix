# Proves the standalone nvf build plumbing end-to-end: a sentinel polarity fed
# to the shared settings comes out the far side as `vim.o.background` in the
# wrapped neovim. "light" is the sentinel (the system default is "dark"), so the
# test exercises the wiring rather than a default. Mirrors the convention of the
# other wrapper tests (assert plumbing, never a specific config value).
{
  pkgs,
  inputs ? null,
}: let
  nvim = import ../nvf/package.nix {
    inherit pkgs;
    neovimConfiguration = inputs.nvf-nixos.lib.neovimConfiguration;
    modules = [
      (import ../nvf/settings.nix {
        stylixEnabled = true;
        polarity = "light";
        meta = {
          enable = false;
          pluginPath = "";
        };
      })
    ];
  };
in
  pkgs.testers.nixosTest {
    name = "nvf-polarity";

    nodes.machine = {
      environment.systemPackages = [nvim];
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("the standalone nvf build is the system nvim"):
          machine.succeed("command -v nvim")

      with subtest("the fed polarity reaches vim.o.background"):
          bg = machine.succeed(
              "HOME=/root nvim --headless '+lua io.write(vim.o.background)' '+qa!' 2>&1"
          ).strip()
          assert bg == "light", f"expected background 'light', got {bg!r}"
    '';
  }
