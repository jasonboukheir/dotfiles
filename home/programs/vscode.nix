{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      arcticicestudio.nord-visual-studio-code
      pkief.material-icon-theme
      github.copilot
    ];

    userSettings = {
      editor = {
        acceptSuggestionOnCommitCharacter = false;
        acceptSuggestionOnEnter = "off";
        accessibilitySupport = "off";
        codeLens = true;
        colorDecorators = true;
        cursorBlinking = "phase";
        cursorStyle = "underline";
        emptySelectionClipboard = false;
        fontFamily = "'FiraCode Nerd Font'";
        fontLigatures = true;
        fontSize = 12;
        fontWeight = "500";
        formatOnPaste = true;
        formatOnSave = true;
        lightbulb.enabled = false;
        minimap.enabled = false;
        multiCursorModifier = "alt";
        renderWhitespace = "selection";
        smoothScrolling = true;
        snippetSuggestions = "top";
        tabCompletion = "onlySnippets";
        tabSize = 4;
        tokenColorCustomizations."[Nord]".textMateRules = [ ];
        wordWrapColumn = 120;
      };
      explorer = {
        autoReveal = true;
        incrementalNaming = "smart";
        openEditors.visible = 0;
      };
      extensions = {
        closeExtensionDetailsOnViewChange = true;
      };
      files = {
        eol = "\n";
        insertFinalNewline = true;
      };
      problems = {
        autoReveal = false;
      };
      security.workspace.trust.untrustedFiles = "open";
      search = {
        collapseResults = "alwaysCollapse";
        useGlobalIgnoreFiles = true;
      };
      telemetry.telemetryLevel = "off";
      terminal = {
        explorerKind = "external";
        external = {
          linuxExec = "tilix";
          osxExex = "kitty";
        };
        integrated = {
          cursorStyle = "underline";
          fontSize = 12;
        };
      };
      window = {
        enableMenuBarMnemonics = false;
        menuBarVisibility = "hidden";
        titleBarStyle = "native";
      };
      workbench = {
        activityBar.visible = true;
        colorCustomizations."[Nord]" = { };
        colorTheme = "Nord";
        commandPalette.preserveInput = true;
        editor = {
          enablePreview = false;
          enablePreviewFromQuickOpen = false;
          focusRecentEditorAfterClose = false;
        };
        enableExperiments = false;
        iconTheme = "material-icon-theme";
        quickOpen.preserveInput = true;
        settings.enableNaturalLanguageSearch = false;
        sideBar.location = "left";
        startupEditor = "welcomePage";
        statusBar.feedback.visible = false;
        renderIndentGuides = "none";
      };

      # Extensions
      "material-icon-theme" = {
        activeIconPack = "react";
        folders = {
          color = "#616e88";
          theme = "classic";
        };
        hideExplorerArrows = true;
        saturation = 0.6;
      };

      nix = {
        enableLanguageServer = true;
        formatterPath = "nixfmt";
        serverPath = "nixd";
        serverSettings.nixd = {
          formatting.command = [ "nixfmt" ];
          options = {
            nix-darwin.expr = "(builtins.getFlake \"\${workspaceFolder}/flake.nix\").darwinConfigurations.\"Jasons-MacBook-Pro\".options";
          };
        };
      };
    };
  };
}
