{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.nushell;
in {
  options = {
    programs.nushell.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to configure Nushell as an interactive shell.";
    };
    programs.nushell.variables = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        A set of environment variables used in the global environment.
        These variables will be set on shell initialisation via system-env.nu.
      '';
    };
    programs.nushell.shellInit = mkOption {
      type = types.lines;
      default = "";
      description = "Script code called during Nushell shell initialisation (added to system-env.nu).";
    };
    programs.nushell.interactiveShellInit = mkOption {
      type = types.lines;
      default = "";
      description = "Script code called during interactive Nushell shell initialisation (added to system-config.nu).";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.nushell];
    environment.shells = [pkgs.nushell];
    environment.etc."nushell/system-env.nu".text = ''
      # /etc/nushell/system-env.nu: DO NOT EDIT -- this file has been generated automatically.
      # This file is sourced for all Nushell instances.
      if ("__NIX_DARWIN_SET_ENVIRONMENT_DONE" not-in $env) {
        $env.__NIX_DARWIN_SET_ENVIRONMENT_DONE = 1
        $env.PATH = [
          $"($env.HOME)/.nix-profile/bin"
          $"/etc/profiles/per-user/($env.USER)/bin"
          "/run/current-system/sw/bin"
          "/nix/var/nix/profiles/default/bin"
          "/usr/local/bin"
          "/usr/bin"
          "/usr/sbin"
          "/bin"
          "/sbin"
        ]
        $env.NIX_PATH = [
          $"darwin-config=($env.HOME)/.nixpkgs/darwin-configuration.nix"
          "/nix/var/nix/profiles/per-user/root/channels"
        ] | str join ":"
        $env.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
        $env.PAGER = "less -R"
        $env.TERMINFO_DIRS = [
          $"($env.HOME)/.nix-profile/share/terminfo"
          $"/etc/profiles/per-user/($env.USER)/share/terminfo"
          "/run/current-system/sw/share/terminfo"
          "/nix/var/nix/profiles/default/share/terminfo"
          "/usr/share/terminfo"
        ] | str join ":"
        $env.XDG_CONFIG_DIRS = [
          $"($env.HOME)/.nix-profile/etc/xdg"
          $"/etc/profiles/per-user/($env.USER)/etc/xdg"
          "/run/current-system/sw/etc/xdg"
          "/nix/var/nix/profiles/default/etc/xdg"
        ] | str join ":"
        $env.XDG_DATA_DIRS = [
          $"($env.HOME)/.nix-profile/share"
          $"/etc/profiles/per-user/($env.USER)/share"
          "/run/current-system/sw/share"
          "/nix/var/nix/profiles/default/share"
        ] | str join ":"
        $env.NIX_USER_PROFILE_DIR = $"/nix/var/nix/profiles/per-user/($env.USER)"
        $env.NIX_PROFILES = [
          "/nix/var/nix/profiles/default"
          "/run/current-system/sw"
          $"/etc/profiles/per-user/($env.USER)"
          $"($env.HOME)/.nix-profile"
        ] | str join " "
        # Preserve TERM if already set
        if ("TERM" in $env) {
          $env.TERM = $env.TERM
        }
      }
      ${concatStringsSep "\n" (mapAttrsToList (n: v: ''$env.${n} = "${v}"'') cfg.variables)}
      ${cfg.shellInit}
    '';
    environment.etc."nushell/system-config.nu".text = ''
      # /etc/nushell/system-config.nu: DO NOT EDIT -- this file has been generated automatically.
      # This file is sourced for all Nushell instances.
      ${cfg.interactiveShellInit}
    '';

    home-manager.users.jasonbk = {
      programs.nushell = {
        extraEnv = ''
          source /etc/nushell/system-env.nu
        '';
        extraConfig = ''
          source /etc/nushell/system-config.nu
        '';
      };
    };
  };
}
