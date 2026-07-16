{
  lib,
  pkgs,
}: let
  tomlFormat = pkgs.formats.toml {};

  sshSigningOptions = {
    enable = lib.mkEnableOption "SSH commit signing in the jj wrapper";

    key = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
      description = "Public SSH signing key, either inline or as a public-key file path.";
    };

    behavior = lib.mkOption {
      type = lib.types.str;
      default = "own";
      description = "Jujutsu signing.behavior value used when SSH signing is enabled.";
    };

    allowedSignersFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Users/me/.ssh/allowed_signers";
      description = "Allowed signers file for verifying SSH signatures.";
    };

    program = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      description = "SSH signing program. When unset and an agent socket is available, the wrapper generates an ssh-keygen shim for that agent.";
    };

    agentSocket = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Users/me/.1password/agent.sock";
      description = "SSH agent socket used by the generated ssh-keygen signing shim. Defaults to my.jujutsu.ssh.agentSocket when unset.";
    };
  };
in {
  name = "jujutsu";
  defaultPackage = "jujutsu";

  options = {
    ssh.agentSocket = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Users/me/.1password/agent.sock";
      description = "SSH agent socket exposed to the jj wrapper for Git transport.";
    };

    signing.ssh = sshSigningOptions;

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {};
      example = {ui.editor = "nvim";};
      description = "Settings baked into this jj wrapper via JJ_CONFIG.";
    };
  };

  # Mapped from the per-user identity/editor into jj's schema; injected below
  # the cascade's mkDefault (see settingsDefaultsFor) so explicit settings and
  # the system→user cascade win.
  settingsDefaults = {
    identity ? null,
    editor ? null,
    ...
  }:
    (lib.optionalAttrs (identity != null && (identity.name != null || identity.email != null)) {
      user =
        (lib.optionalAttrs (identity.name != null) {name = identity.name;})
        // (lib.optionalAttrs (identity.email != null) {email = identity.email;});
    })
    // (lib.optionalAttrs (editor != null) (let
      exe = lib.getExe editor;
      # jj hands its editors on-disk paths ($left/$base/$right/$output), not
      # revs. nvim rides diffview-plus.nvim (baked into the nvf editor build,
      # see nvf/body.nix): :DiffviewMergeFiles for the 3-way merge editor and
      # :DiffviewDiffDirs for the interactive diff editor, both VCS-less.
      # Plain vim falls back to jj's builtin vimdiff tool with only its program
      # repointed; anything else (a bare editor) stays editor-only.
      mainProgram = editor.meta.mainProgram or (lib.getName editor);

      # merge-tool-edits-conflict-markers: jj pre-fills $output with conflict
      # markers and reparses them on exit, so a partial resolve is preserved.
      diffviewTooling = {
        ui = {
          merge-editor = "diffview";
          diff-editor = "diffview";
        };
        merge-tools.diffview = {
          program = exe;
          merge-args = ["-c" "DiffviewMergeFiles $output $base $left $right"];
          merge-tool-edits-conflict-markers = true;
          edit-args = ["-c" "DiffviewDiffDirs $left $right $output"];
          diff-args = ["-c" "DiffviewDiffDirs $left $right"];
        };
      };

      vimdiffTooling = {
        ui.merge-editor = "vimdiff";
        merge-tools.vimdiff.program = exe;
      };

      editorTooling =
        if mainProgram == "nvim"
        then diffviewTooling
        else if mainProgram == "vim"
        then vimdiffTooling
        else {};
    in
      # ui assembled in one piece: a top-level `//` would replace the whole
      # `ui` attrset and silently drop ui.editor.
      lib.recursiveUpdate {ui.editor = exe;} editorTooling));

  assertions = {cfg, ...}: [
    {
      assertion = !cfg.signing.ssh.enable || cfg.signing.ssh.key != null;
      message = "my.jujutsu.signing.ssh.key must be set when SSH signing is enabled.";
    }
    {
      assertion = !(cfg.signing.ssh.agentSocket != null && cfg.signing.ssh.program != null);
      message = "Set only one of my.jujutsu.signing.ssh.agentSocket or my.jujutsu.signing.ssh.program.";
    }
  ];

  build = {
    cfg,
    pkgs,
    ...
  }: let
    signCfg = cfg.signing.ssh;
    signingAgentSocket =
      if signCfg.agentSocket != null
      then signCfg.agentSocket
      else cfg.ssh.agentSocket;
    generatedSigningProgram = pkgs.writeShellApplication {
      name = "my-jj-ssh-sign";
      runtimeInputs = [pkgs.openssh];
      text = ''
        export SSH_AUTH_SOCK=${lib.escapeShellArg signingAgentSocket}
        exec ssh-keygen "$@"
      '';
    };
    signingProgram =
      if signCfg.program != null
      then signCfg.program
      else if signingAgentSocket != null
      then lib.getExe generatedSigningProgram
      else null;
    sshSigningSettings =
      lib.optionalAttrs signCfg.enable
      (lib.foldl' lib.recursiveUpdate {} [
        {
          signing = {
            behavior = signCfg.behavior;
            backend = "ssh";
          };
        }
        (lib.optionalAttrs (signCfg.key != null) {
          signing.key = signCfg.key;
        })
        (lib.optionalAttrs (signingProgram != null || signCfg.allowedSignersFile != null) {
          signing.backends.ssh =
            (lib.optionalAttrs (signCfg.allowedSignersFile != null) {
              allowed-signers = signCfg.allowedSignersFile;
            })
            // (lib.optionalAttrs (signingProgram != null) {
              program = signingProgram;
            });
        })
      ]);
    bakedConfig = lib.recursiveUpdate cfg.settings sshSigningSettings;
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "jj";
      env =
        {
          JJ_CONFIG = tomlFormat.generate "jj-config.toml" bakedConfig;
        }
        // lib.optionalAttrs (cfg.ssh.agentSocket != null) {
          SSH_AUTH_SOCK = cfg.ssh.agentSocket;
        };
    };
}
