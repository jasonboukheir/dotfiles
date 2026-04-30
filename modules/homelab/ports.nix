{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.homelab.ports;

  hexTable = listToAttrs (genList (i:
    nameValuePair (substring i 1 "0123456789abcdef") i)
  16);

  hexToInt = s:
    foldl' (acc: c: acc * 16 + hexTable.${c}) 0 (stringToCharacters s);

  hashToInt = chars: name:
    hexToInt (substring 0 chars (builtins.hashString "sha256" name));

  span = cfg.range.to - cfg.range.from + 1;

  desiredPort = name: cfg.range.from + (mod (hashToInt 8 name) span);

  pinned = filterAttrs (_: v: isInt v) cfg.allocate;
  autoNames = sort lessThan (attrNames (filterAttrs (_: v: v == "auto") cfg.allocate));
  reservedPorts = attrValues cfg.reserved;

  assignAuto = state: name: let
    desired = desiredPort name;
    probe = offset:
      if offset >= span
      then null
      else let
        candidate = cfg.range.from + (mod (desired - cfg.range.from + offset) span);
      in
        if elem candidate state.taken
        then probe (offset + 1)
        else candidate;
    port = probe 0;
  in
    if port == null
    then throw "homelab.ports: no free port in range [${toString cfg.range.from}, ${toString cfg.range.to}] for ${name}"
    else {
      taken = state.taken ++ [port];
      result = state.result // {${name} = port;};
    };

  initial = {
    taken = (attrValues pinned) ++ reservedPorts;
    result = pinned;
  };

  final = foldl' assignAuto initial autoNames;

  allTaken = (attrValues final.result) ++ reservedPorts;
  duplicates = lib.subtractLists (lib.unique allTaken) allTaken;
in {
  options.homelab.ports = {
    range = mkOption {
      description = "Inclusive port range from which auto-allocations are vended.";
      default = {};
      type = types.submodule {
        options = {
          from = mkOption {
            type = types.port;
            default = 3000;
          };
          to = mkOption {
            type = types.port;
            default = 6999;
          };
        };
      };
    };

    allocate = mkOption {
      description = ''
        Per-service port allocations. Set the value to an integer to pin a port
        (escape hatch for services with externally-fixed ports), or to "auto"
        to vend a deterministic port from the range based on a hash of the
        attribute name. Reading config.homelab.ports.values.<name>
        returns the resolved port.
      '';
      default = {};
      example = literalExpression ''
        {
          coder = "auto";
          searx = 3300;
        }
      '';
      type = types.attrsOf (types.either types.port (types.enum ["auto"]));
    };

    reserved = mkOption {
      description = ''
        Well-known infrastructure ports that auto-vending should treat as taken
        even though no entry in `allocate` declares them. Use this for ports
        bound by services outside the registry (postgres, redis, NUT, etc.) so
        hash-vended app ports never collide with them. Pinned values in
        `allocate` are also checked against these for duplicates.
      '';
      default = {
        postgres = 5432;
        redis = 6379;
        mysql = 3306;
        ssh = 22;
        dns = 53;
        http = 80;
        https = 443;
        smtp = 25;
        smtp-submission = 587;
        smtps = 465;
        imap = 143;
        imaps = 993;
        nut-upsd = 3493;
        prometheus-node = 9100;
      };
      type = types.attrsOf types.port;
    };

    values = mkOption {
      type = types.attrsOf types.port;
      readOnly = true;
      description = "Resolved port for each entry in allocate.";
    };
  };

  config = mkIf config.homelab.enable {
    homelab.ports.values = final.result;

    assertions = [
      {
        assertion = cfg.range.from <= cfg.range.to;
        message = "homelab.ports.range.from must be <= range.to";
      }
      {
        assertion = duplicates == [];
        message = "homelab.ports has duplicate values: ${toString (lib.unique duplicates)}. Allocations: ${builtins.toJSON final.result}; Reserved: ${builtins.toJSON cfg.reserved}";
      }
    ];
  };
}
