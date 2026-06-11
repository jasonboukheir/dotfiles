# Per-user plumbing for my.weechat: irc defaults, extraConfig, and scripts are
# baked into the wrapper's --run-command, and a headless run proves the init
# commands actually execute (the non-default values survive quit-with-save).
{
  pkgs,
  inputs ? null,
}: let
  sentinel = "my-weechat-wrapper-1f2e";
in
  pkgs.testers.nixosTest {
    name = "my-weechat-wrapper";

    nodes.machine = {
      imports = [../nixos.nix];

      users.users.tester = {
        isNormalUser = true;
        my.weechat = {
          enable = true;
          irc.enable = true;
          scripts = [pkgs.weechatScripts.weechat-autosort];
          extraConfig = ''
            /set weechat.look.buffer_time_format "${sentinel}"
          '';
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      weechat = machine.succeed(
          "su -l tester -c 'readlink -f $(command -v weechat)'"
      ).strip()

      with subtest("irc defaults, extraConfig, and scripts are baked into --run-command"):
          machine.succeed(f"grep -q 'run-command' {weechat}")
          machine.succeed(f"grep -q '/set irc.look.smart_filter on' {weechat}")
          machine.succeed(f"grep -q '${sentinel}' {weechat}")
          machine.succeed(f"grep -q '/script load .*autosort.py' {weechat}")

      with subtest("a headless run executes the init and persists non-default values"):
          # weechat-headless writes config files only on /save (not at startup,
          # not on SIGTERM). Multiple --run-command args execute in argv order,
          # so this one runs before the wrapper's baked init — /wait defers the
          # /save until after the init's /set commands have been applied.
          machine.succeed(
              "su -l tester -c \"weechat-headless -r '/wait 2 /save;/wait 4 /quit'\""
          )
          machine.succeed(
              "grep -q 'server_buffer = independent' ~tester/.config/weechat/irc.conf"
          )
          machine.succeed("grep -q '${sentinel}' ~tester/.config/weechat/weechat.conf")
    '';
  }
