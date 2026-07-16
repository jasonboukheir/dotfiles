{
  lib,
  pkgs,
}: let
  gitIniFormat = pkgs.formats.gitIni {};

  lfsFilter = {
    clean = "git-lfs clean -- %f";
    smudge = "git-lfs smudge -- %f";
    process = "git-lfs filter-process";
    required = true;
  };

  sshSigningOptions = {
    enable = lib.mkEnableOption "SSH commit signing in the git wrapper";

    key = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
      description = "Public SSH signing key, either inline or as a public-key file path.";
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
      description = "SSH agent socket used by the generated ssh-keygen signing shim. Defaults to my.git.ssh.agentSocket when unset.";
    };
  };
in {
  name = "git";
  defaultPackage = "git";

  options = {
    ssh = {
      program = lib.mkOption {
        type = lib.types.str;
        default = lib.getExe' pkgs.openssh "ssh";
        defaultText = lib.literalExpression ''lib.getExe' pkgs.openssh "ssh"'';
        example = "/usr/bin/ssh";
        description = "SSH executable used by GIT_SSH_COMMAND for git transport.";
      };

      agentSocket = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/Users/me/.1password/agent.sock";
        description = "SSH agent socket used by git transport in this wrapper.";
      };

      match = lib.mkOption {
        type = lib.types.str;
        default = "Host *";
        example = "Host github.com";
        description = "OpenSSH config match line used for the generated git transport config.";
      };

      identityFiles = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [
          "/Users/me/.ssh/id_ed25519-cert.pub"
          "/Users/me/.ssh/id_ed25519.pub"
        ];
        description = "IdentityFile entries added to the generated git transport config.";
      };

      identitiesOnly = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the generated git transport config should set IdentitiesOnly yes.";
      };

      extraOptions = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = {
          PreferredAuthentications = "publickey";
          PubkeyAuthentication = "yes";
        };
        description = "Extra OpenSSH options added to the generated git transport config.";
      };

      extraConfigAfter = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = ''
          Match all
          Include /etc/ssh/ssh_config
        '';
        description = "Raw OpenSSH config appended after the generated git transport match block.";
      };
    };

    signing.ssh = sshSigningOptions;

    lfs.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Put git-lfs on the wrapper PATH and bake its filters into GIT_CONFIG_GLOBAL.";
    };

    ignores = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [".DS_Store"];
      description = "Patterns baked into a gitignore and wired as core.excludesFile.";
    };

    settings = lib.mkOption {
      type = gitIniFormat.type;
      default = {};
      example = {init.defaultBranch = "main";};
      description = "Settings baked into this git wrapper via GIT_CONFIG_GLOBAL.";
    };
  };

  # Mapped from the per-user identity/editor into git's schema; injected below
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
      # merge.tool/diff.tool take a *tool name* git resolves, not a command.
      # nvim rides diffview-plus.nvim (baked into the nvf editor build, see
      # nvf/body.nix) wired as a cmd-based custom tool; plain vim falls back to
      # git's builtin vimdiff table via {merge,diff}tool.<name>.path. Program
      # name from metadata, not baseNameOf exe: a store-path basename carries
      # string context, which attribute names reject.
      mainProgram = editor.meta.mainProgram or (lib.getName editor);

      # DiffviewOpen auto-detects an in-progress merge and opens its 3-way
      # mergetool view; trustExitCode lets a clean exit mark the file resolved.
      # diffview is rev-range oriented, so per-file `git difftool <rev>` would
      # reopen the same view for every file — `git dv [rev-range]` opens it once.
      diffviewTooling = {
        merge.tool = "diffview";
        mergetool = {
          prompt = false;
          keepBackup = false;
          diffview = {
            cmd = "${exe} -n -c \"DiffviewOpen\" \"$MERGED\"";
            trustExitCode = true;
          };
        };
        diff.tool = "diffview";
        difftool = {
          prompt = false;
          diffview.cmd = "${exe} -n -c \"DiffviewOpen\"";
        };
        alias.dv = "!f() { ${exe} -c \"DiffviewOpen $*\"; }; f";
      };

      vimdiffTooling = {
        merge.tool = "vimdiff";
        mergetool.vimdiff.path = exe;
        diff.tool = "vimdiff";
        difftool.vimdiff.path = exe;
      };

      editorTooling =
        if mainProgram == "nvim"
        then diffviewTooling
        else if mainProgram == "vim"
        then vimdiffTooling
        else {};
    in
      {core.editor = exe;} // editorTooling));

  assertions = {cfg, ...}: [
    {
      assertion = !cfg.signing.ssh.enable || cfg.signing.ssh.key != null;
      message = "my.git.signing.ssh.key must be set when SSH signing is enabled.";
    }
    {
      assertion = !(cfg.signing.ssh.agentSocket != null && cfg.signing.ssh.program != null);
      message = "Set only one of my.git.signing.ssh.agentSocket or my.git.signing.ssh.program.";
    }
  ];

  build = {
    cfg,
    pkgs,
    ...
  }: let
    excludesFile = pkgs.writeText "gitignore" (lib.concatStringsSep "\n" cfg.ignores);
    signCfg = cfg.signing.ssh;
    signingAgentSocket =
      if signCfg.agentSocket != null
      then signCfg.agentSocket
      else cfg.ssh.agentSocket;
    generatedSigningProgram = pkgs.writeShellApplication {
      name = "my-git-ssh-sign";
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
        (lib.optionalAttrs (signCfg.key != null) {
          user.signingKey = signCfg.key;
        })
        {
          gpg.format = "ssh";
          commit.gpgsign = true;
        }
        (lib.optionalAttrs (signingProgram != null || signCfg.allowedSignersFile != null) {
          "gpg \"ssh\"" =
            (lib.optionalAttrs (signCfg.allowedSignersFile != null) {
              allowedSignersFile = signCfg.allowedSignersFile;
            })
            // (lib.optionalAttrs (signingProgram != null) {
              program = signingProgram;
            });
        })
      ]);
    bakedConfig = lib.foldl' lib.recursiveUpdate {} [
      cfg.settings
      sshSigningSettings
      (lib.optionalAttrs (cfg.ignores != []) {core.excludesFile = "${excludesFile}";})
      (lib.optionalAttrs cfg.lfs.enable {filter.lfs = lfsFilter;})
    ];
    sshConfigEnabled =
      cfg.ssh.agentSocket
      != null
      || cfg.ssh.identityFiles != []
      || cfg.ssh.identitiesOnly
      || cfg.ssh.extraOptions != {}
      || cfg.ssh.extraConfigAfter != "";
    sshConfig = pkgs.writeText "git-ssh-config" (lib.concatLines (
      [cfg.ssh.match]
      ++ lib.optional (cfg.ssh.agentSocket != null) "  IdentityAgent \"${cfg.ssh.agentSocket}\""
      ++ map (identityFile: "  IdentityFile \"${identityFile}\"") cfg.ssh.identityFiles
      ++ lib.optional cfg.ssh.identitiesOnly "  IdentitiesOnly yes"
      ++ lib.mapAttrsToList (name: value: "  ${name} ${value}") cfg.ssh.extraOptions
      ++ lib.optional (cfg.ssh.extraConfigAfter != "") cfg.ssh.extraConfigAfter
    ));
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "git";
      extraPaths = lib.optional cfg.lfs.enable pkgs.git-lfs;
      env =
        {
          GIT_CONFIG_GLOBAL = gitIniFormat.generate "gitconfig" bakedConfig;
        }
        // lib.optionalAttrs sshConfigEnabled {
          GIT_SSH_COMMAND = "${cfg.ssh.program} -F ${sshConfig}";
        }
        // lib.optionalAttrs (cfg.ssh.agentSocket != null) {
          SSH_AUTH_SOCK = cfg.ssh.agentSocket;
        };
    };
}
