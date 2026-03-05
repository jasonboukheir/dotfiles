{pkgs, ...}: {
  programs.vscode-fb = {
    enable = true;
    stylixColors = true;
    extensions = with pkgs.vscode-extensions; [
      pkief.material-icon-theme
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
        fontLigatures = true;
        formatOnPaste = true;
        formatOnSave = true;
        lightbulb.enabled = "off";
        minimap.enabled = false;
        multiCursorModifier = "alt";
        renderWhitespace = "selection";
        smoothScrolling = true;
        snippetSuggestions = "top";
        tabCompletion = "onlySnippets";
        tabSize = 4;
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
          linuxExec = "ghostty";
          osxExec = "ghostty";
        };
        integrated = {
          cursorStyle = "underline";
        };
      };
      window = {
        autoDetectColorScheme = true;
        autoDetectHighContrast = true;
        titleBarStyle = "native";
      };
      workbench = {
        activityBar.visible = true;
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
      };

      # Extensions
      "material-icon-theme" = {
        activeIconPack = "react";
        folders = {
          color = "#616e88";
          theme = "classic";
        };
        saturation = 0.6;
      };
    };
  };
}
