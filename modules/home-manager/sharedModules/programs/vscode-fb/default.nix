{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.vscode-fb;
  jq = "${pkgs.jq}/bin/jq";

  # Extract the extension directory from a derivation
  extensionDir = ext: "${ext}/share/vscode/extensions/${ext.vscodeExtUniqueId}";
  extensionDirName = ext: "${ext.vscodeExtUniqueId}-${ext.version}";

  # Generate a registry entry for extensions.json
  # path is set at activation time via jq since it depends on $HOME
  registryEntry = ext: {
    identifier = {
      id = ext.vscodeExtUniqueId;
      uuid = ext.vscodeExtUniqueId;
    };
    version = ext.version;
    location = {
      "$mid" = 1;
      scheme = "file";
    };
    relativeLocation = extensionDirName ext;
    metadata = {
      installedTimestamp = 0;
      source = "nix";
      id = ext.vscodeExtUniqueId;
      publisherId = ext.vscodeExtPublisher;
      publisherDisplayName = ext.vscodeExtPublisher;
      targetPlatform = "undefined";
      updated = false;
      private = false;
      isPreReleaseVersion = false;
      hasPreReleaseVersion = false;
    };
  };

  # All nix-managed extension IDs for filtering in jq
  nixExtensionIds = map (ext: ext.vscodeExtUniqueId) cfg.extensions;
  nixExtensionIdsJson = builtins.toJSON nixExtensionIds;

  # Registry entries for all extensions
  registryEntries = map registryEntry cfg.extensions;
  registryEntriesJson = builtins.toJSON registryEntries;
in {
  options.programs.vscode-fb = {
    enable = lib.mkEnableOption "VS Code @ FB with Stylix theming and declarative settings";

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "List of VS Code extension derivations to install.";
    };

    userSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Additional VS Code settings to merge into settings.json.";
    };

    settingsPath = lib.mkOption {
      type = lib.types.str;
      default = "Library/Application Support/VS Code @ FB/User/settings.json";
      description = "Relative path from $HOME to the VS Code @ FB settings.json.";
    };

    extensionsDir = lib.mkOption {
      type = lib.types.str;
      default = ".vscode-fb-mkt/extensions";
      description = "Relative path from $HOME to the VS Code @ FB extensions directory.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Stylix theme extension and settings
    (lib.mkIf config.stylix.enable (let
      colors = config.lib.stylix.colors;
      fonts = config.stylix.fonts;

      themeExtension = pkgs.runCommandLocal "stylix-vscode" {
        vscodeExtUniqueId = "stylix.stylix";
        vscodeExtPublisher = "stylix";
        version = "0.0.0";
        theme = builtins.toJSON (import ./templates/theme.nix colors);
        passAsFile = ["theme"];
      } ''
        mkdir -p "$out/share/vscode/extensions/$vscodeExtUniqueId/themes"
        ln -s ${./package.json} "$out/share/vscode/extensions/$vscodeExtUniqueId/package.json"
        cp "$themePath" "$out/share/vscode/extensions/$vscodeExtUniqueId/themes/stylix.json"
      '';
    in {
      programs.vscode-fb.extensions = [themeExtension];
      programs.vscode-fb.userSettings = import ./templates/settings.nix fonts;
    }))

    # Install extensions via home.file and register them in extensions.json
    (lib.mkIf (cfg.extensions != []) {
      home.file = lib.listToAttrs (map (ext: {
        name = "${cfg.extensionsDir}/${extensionDirName ext}";
        value.source = extensionDir ext;
      }) cfg.extensions);

      home.activation.vscodeAtFbExtensions = lib.hm.dag.entryAfter ["writeBoundary"] ''
        extensionsJson="$HOME/${cfg.extensionsDir}/extensions.json"
        if [ -f "$extensionsJson" ]; then
          ${jq} \
            --argjson nixIds '${nixExtensionIdsJson}' \
            --argjson nixEntries '${registryEntriesJson}' \
            --arg extDir "$HOME/${cfg.extensionsDir}" \
            '
              [.[] | select(.identifier.id as $id | $nixIds | index($id) | not)]
              + [$nixEntries[] | .location.path = ($extDir + "/" + .relativeLocation)]
            ' \
            "$extensionsJson" > "$extensionsJson.tmp"
          mv "$extensionsJson.tmp" "$extensionsJson"
        fi
      '';
    })

    # Activation script to merge settings into the imperative settings.json
    (lib.mkIf (cfg.userSettings != {}) (let
      settingsJson = pkgs.writeText "vscode-fb-nix-settings.json" (builtins.toJSON cfg.userSettings);
    in {
      home.activation.vscodeAtFbSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
        settingsFile="$HOME/${cfg.settingsPath}"
        if [ -f "$settingsFile" ]; then
          ${jq} -s '.[0] * .[1]' "$settingsFile" "${settingsJson}" > "$settingsFile.tmp"
          mv "$settingsFile.tmp" "$settingsFile"
        fi
      '';
    }))
  ]);
}
