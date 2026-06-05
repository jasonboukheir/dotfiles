{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.weechat;

  ircInit = lib.optionalString cfg.irc.enable ''
    /set irc.look.server_buffer independent
    /set irc.look.color_nicks_in_names on
    /set irc.look.smart_filter on
  '';

  init = lib.concatStringsSep "\n" (lib.filter (s: s != "") [
    ircInit
    cfg.extraConfig
  ]);

  weechatConfigured = cfg.package.override {
    configure = {availablePlugins, ...}: {
      plugins = builtins.attrValues (builtins.removeAttrs availablePlugins ["php"]);
      inherit (cfg) scripts;
      inherit init;
    };
  };
in {
  options.programs.weechat = {
    enable = lib.mkEnableOption "WeeChat chat client";

    package = lib.mkPackageOption pkgs "weechat" {};

    irc.enable = lib.mkEnableOption ''
      IRC look-and-feel defaults. Servers, nick, and SASL credentials are
      configured manually at runtime with /server and /secure so that no
      secrets land in the world-readable Nix store
    '';

    scripts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "with pkgs.weechatScripts; [weechat-autosort colorize_nicks]";
      description = "WeeChat scripts to load on startup.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        WeeChat commands run on every startup via --run-command, one command
        per line. Use idempotent /set commands. Never place secrets here: this
        string is written to the world-readable Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [weechatConfigured];
  };
}
