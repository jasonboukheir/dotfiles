# The shared ssh client Host blocks (brutus/litus multiplexing + zmx session
# attach, pibitcoin agent forwarding, 1Password IdentityAgent), rendered to
# ssh_config text. Single source of truth for every host's client config;
# consumers feed the text to their platform's mechanism — NixOS/nix-darwin
# `programs.ssh.extraConfig`, or a seeded real `~/.ssh/config` on the
# standalone-HM fedora box (issue #46).
{
  lib,
  # 1Password agent socket the IdentityAgent block points at; null omits the
  # block entirely (hosts without a 1Password agent).
  identityAgent ? null,
  # The Host/Match line the IdentityAgent applies under. Block order makes it
  # the fallback: ssh takes the first obtained value per option, and this block
  # is rendered last.
  identityAgentMatch ? "Host *",
}: let
  multiplexing = {
    ControlMaster = "auto";
    ControlPath = "~/.ssh/control-%C";
    ControlPersist = "10m";
  };

  zmxSession = host:
    multiplexing
    // {
      HostName = host;
      ForwardAgent = "yes";
      RemoteCommand = "sh -c 'zmx attach \"\${1#*.}\"' _ %n";
      RequestTTY = "yes";
    };

  blocks =
    [
      {
        match = "Host brutus";
        settings = multiplexing // {ForwardAgent = "yes";};
      }
      {
        match = "Host brutus.*";
        settings = zmxSession "brutus";
      }
      {
        match = "Host litus";
        settings = multiplexing // {ForwardAgent = "yes";};
      }
      {
        match = "Host litus.*";
        settings = zmxSession "litus";
      }
      {
        match = "Host pibitcoin";
        settings.ForwardAgent = "yes";
      }
    ]
    ++ lib.optional (identityAgent != null) {
      match = identityAgentMatch;
      settings.IdentityAgent = "\"${identityAgent}\"";
    };

  renderBlock = {
    match,
    settings,
  }:
    lib.concatLines (
      [match] ++ lib.mapAttrsToList (key: value: "  ${key} ${value}") settings
    );
in
  lib.concatStringsSep "\n" (map renderBlock blocks)
